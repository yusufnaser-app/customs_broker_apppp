import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/fee_calculator.dart';
import '../../domain/entities/declaration.dart';
import '../../domain/entities/declaration_item.dart';
import 'declaration_form_screen.dart';
import '../../../documents/presentation/screens/advanced_documents_screen.dart';

class DeclarationDetailsScreen extends StatefulWidget {
  final String declarationId;

  const DeclarationDetailsScreen({super.key, required this.declarationId});

  @override
  State<DeclarationDetailsScreen> createState() => _DeclarationDetailsScreenState();
}

class _DeclarationDetailsScreenState extends State<DeclarationDetailsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Declaration? _declaration;
  List<DeclarationItem> _items = [];
  FeeBreakdown? _feeBreakdown;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final db = await _dbHelper.database;
      
      // تحميل الإقرار
      final declarations = await db.rawQuery('''
        SELECT d.*, c.name as client_name, t.name as trader_name, s.name as supplier_name
        FROM declarations d
        LEFT JOIN clients c ON d.client_id = c.id
        LEFT JOIN traders t ON d.trader_id = t.id
        LEFT JOIN suppliers s ON d.supplier_id = s.id
        WHERE d.id = ?
      ''', [widget.declarationId]);
      
      if (declarations.isNotEmpty) {
        final declaration = Declaration.fromMap(
          declarations.first,
          clientName: declarations.first['client_name'] as String?,
          traderName: declarations.first['trader_name'] as String?,
          supplierName: declarations.first['supplier_name'] as String?,
        );
        
        // تحميل الأصناف
        final itemsResult = await db.query(
          'declaration_items',
          where: 'declaration_id = ?',
          whereArgs: [widget.declarationId],
        );
        
        final items = itemsResult.map((item) => DeclarationItem.fromMap(item)).toList();
        
        // حساب الرسوم
        final feeCalculator = FeeCalculator(db);
        final fees = await feeCalculator.calculateFees(declaration.invoiceValueUsd);
        
        setState(() {
          _declaration = declaration;
          _items = items;
          _feeBreakdown = fees;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addItem() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _AddItemDialog(dbHelper: _dbHelper),
    );
    
    if (result != null) {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      
      await db.insert('declaration_items', {
        'id': const Uuid().v4(),
        'declaration_id': widget.declarationId,
        'hs_code': result['hs_code']!,
        'item_name': result['item_name']!,
        'description': result['description'] ?? '',
        'quantity': double.tryParse(result['quantity']!) ?? 0,
        'weight': double.tryParse(result['weight'] ?? '0'),
        'unit': result['unit']!,
        'value': double.tryParse(result['value']!) ?? 0,
        'origin_country': result['origin_country'] ?? '',
        'created_at': now,
      });
      
      // تحديث عدد الأصناف
      await db.update(
        'declarations',
        {'items_count': _items.length + 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [widget.declarationId],
      );
      
      _loadData();
    }
  }

  Future<void> _confirmDeclaration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإقرار'),
        content: const Text('هل أنت متأكد من اعتماد هذا الإقرار؟ سيتم حفظ نسخة تاريخية من الرسوم ولن تتغير مستقبلاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
    
    if (confirm == true && _declaration != null && _feeBreakdown != null) {
      final db = await _dbHelper.database;
      final feeCalculator = FeeCalculator(db);

      await feeCalculator.saveSnapshot(_declaration!.id, _feeBreakdown!);

      // حفظ قاعدة رسوم مستقلة لكل صنف (حسب HS Code الخاص به) لاستخدامها كنموذج لاحقًا
      for (final item in _items) {
        final itemCalculator = FeeCalculator(db, hsCode: item.hsCode);
        final itemBreakdown = await itemCalculator.calculateFees(item.value);
        await itemCalculator.saveItemFeeRule(item.hsCode, item.itemName, itemBreakdown);
      }

      await db.update(
        'declarations',
        {'status': 'completed', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [widget.declarationId],
      );
      
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اعتماد الإقرار بنجاح'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الإقرار')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_declaration == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الإقرار')),
        body: const Center(child: Text('الإقرار غير موجود')),
      );
    }
    
    final declaration = _declaration!;
    final currencyFormatter = NumberFormat('#,##0.00');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('إقرار #${declaration.declarationNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file_rounded),
            tooltip: 'المرفقات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdvancedDocumentsScreen(declarationId: declaration.id),
                ),
              );
            },
          ),
          if (declaration.status == 'draft')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeclarationFormScreen(declarationId: declaration.id),
                  ),
                );
                if (result == true) _loadData();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // حالة الإقرار
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'حالة الإقرار: ${declaration.status == 'draft' ? 'مسودة' : declaration.status == 'completed' ? 'مكتمل' : declaration.status}',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // معلومات أساسية
            _buildDetailCard('معلومات الإقرار', [
              _buildDetailRow('رقم الإقرار', declaration.declarationNumber),
              _buildDetailRow('رقم البيان', declaration.statementNumber ?? '-'),
              _buildDetailRow('تاريخ البيان', declaration.statementDate ?? '-'),
              _buildDetailRow('نوع البيان', declaration.statementType ?? '-'),
              _buildDetailRow('المركز الجمركي', declaration.customsCenter ?? '-'),
            ]),
            const SizedBox(height: 16),
            
            _buildDetailCard('معلومات العميل', [
              _buildDetailRow('العميل', declaration.clientName ?? '-'),
              _buildDetailRow('المستورد', declaration.traderName ?? '-'),
              _buildDetailRow('المورد', declaration.supplierName ?? '-'),
            ]),
            const SizedBox(height: 16),
            
            _buildDetailCard('معلومات الشحن والفاتورة', [
              _buildDetailRow('بلد المنشأ', declaration.originCountry ?? '-'),
              _buildDetailRow('بلد التصدير', declaration.exportCountry ?? '-'),
              _buildDetailRow('وسيلة النقل', declaration.transportMethod ?? '-'),
              _buildDetailRow('رقم الحاوية', declaration.containerNumber ?? '-'),
              _buildDetailRow('رقم الفاتورة', declaration.invoiceNumber ?? '-'),
              _buildDetailRow('تاريخ الفاتورة', declaration.invoiceDate ?? '-'),
              _buildDetailRow('قيمة الفاتورة', '${currencyFormatter.format(declaration.invoiceValueUsd)} ${declaration.currency}'),
              _buildDetailRow('سعر الصرف', '${currencyFormatter.format(declaration.exchangeRate)} ريال'),
            ]),
            const SizedBox(height: 16),
            
            // الأصناف
            _buildItemsSection(),
            const SizedBox(height: 16),
            
            // كشف الرسوم
            if (_feeBreakdown != null) ...[
              _buildFeesSection(),
              const SizedBox(height: 24),
            ],
            
            // أزرار الإجراءات
            if (declaration.status == 'draft') ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _confirmDeclaration,
                  icon: const Icon(Icons.check_circle),
                  label: Text('اعتماد الإقرار', style: GoogleFonts.cairo(fontSize: 18)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الأصناف (${_items.length})', style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary)),
                if (_declaration?.status == 'draft')
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة صنف'),
                  ),
              ],
            ),
            const Divider(),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('لا توجد أصناف مضافة', style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              ..._items.map((item) => _buildItemCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(DeclarationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.itemName, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
              Text(item.hsCode, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 6),
          Text('الكمية: ${item.quantity} ${item.unit} | القيمة: ${NumberFormat('#,##0.00').format(item.value)} \$',
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFeesSection() {
    final fees = _feeBreakdown!;
    final currencyFormatter = NumberFormat('#,##0');
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('كشف الرسوم', style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const Divider(),
            
            _buildFeesRow('قيمة الفاتورة (ريال)', '${currencyFormatter.format(fees.invoiceValueYer)} ر.ي'),
            const SizedBox(height: 8),
            
            Text('الرسوم النسبية:', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ...fees.relativeFees.map((fee) => _buildFeesRow(
              '  ${fee.name} (${fee.rate}%)',
              '${currencyFormatter.format(fee.amount)} ر.ي',
            )),
            const SizedBox(height: 8),
            
            Text('الرسوم الثابتة:', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ...fees.fixedFees.map((fee) => _buildFeesRow(
              '  ${fee.name}',
              '${currencyFormatter.format(fee.amount)} ر.ي',
            )),
            const Divider(),
            
            _buildFeesRow('إجمالي الرسوم', '${currencyFormatter.format(fees.grandTotal)} ر.ي',
                bold: true, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildFeesRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.cairo(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: GoogleFonts.cairo(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const _AddItemDialog({required this.dbHelper});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _hsCodeController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _weightController = TextEditingController();
  final _valueController = TextEditingController();
  String _selectedUnit = 'قطعة';
  String _selectedOriginCountry = 'اليمن';
  List<Map<String, dynamic>> _tariffSearchResults = [];
  bool _isSearching = false;

  final List<String> _units = ['قطعة', 'كيلوجرام', 'طن', 'متر', 'لتر', 'كرتون', 'صندوق', 'بالة'];
  final List<String> _countries = ['اليمن', 'السعودية', 'الإمارات', 'الصين', 'الهند', 'تركيا'];

  Future<void> _searchTariff(String query) async {
    if (query.length < 2) {
      setState(() => _tariffSearchResults = []);
      return;
    }
    
    setState(() => _isSearching = true);
    
    final db = await widget.dbHelper.database;
    final results = await db.query(
      'tariff',
      where: 'hs_code LIKE ? OR item_name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 10,
    );
    
    setState(() {
      _tariffSearchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة صنف جديد'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _hsCodeController,
                decoration: const InputDecoration(labelText: 'رمز التعرفة HS Code *'),
                onChanged: _searchTariff,
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              if (_tariffSearchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _tariffSearchResults.length,
                    itemBuilder: (context, index) {
                      final item = _tariffSearchResults[index];
                      return ListTile(
                        dense: true,
                        title: Text(item['item_name'] as String, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(item['hs_code'] as String, style: const TextStyle(fontSize: 12)),
                        onTap: () {
                          _itemNameController.text = item['item_name'] as String;
                          _hsCodeController.text = item['hs_code'] as String;
                          if (item['unit'] != null) {
                            _selectedUnit = item['unit'] as String;
                          }
                          setState(() => _tariffSearchResults = []);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _itemNameController,
                decoration: const InputDecoration(labelText: 'اسم الصنف *'),
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'الوصف'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'الكمية *'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(labelText: 'الوحدة'),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(labelText: 'الوزن (كجم)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _valueController,
                      decoration: const InputDecoration(labelText: 'القيمة (\$) *'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedOriginCountry,
                decoration: const InputDecoration(labelText: 'بلد المنشأ'),
                items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedOriginCountry = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'hs_code': _hsCodeController.text,
                'item_name': _itemNameController.text,
                'description': _descriptionController.text,
                'quantity': _quantityController.text,
                'weight': _weightController.text,
                'unit': _selectedUnit,
                'value': _valueController.text,
                'origin_country': _selectedOriginCountry,
              });
            }
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _hsCodeController.dispose();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _weightController.dispose();
    _valueController.dispose();
    super.dispose();
  }
}
