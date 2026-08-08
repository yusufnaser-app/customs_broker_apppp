import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class DeclarationFormScreen extends StatefulWidget {
  final String? declarationId;
  
  const DeclarationFormScreen({super.key, this.declarationId});

  @override
  State<DeclarationFormScreen> createState() => _DeclarationFormScreenState();
}

class _DeclarationFormScreenState extends State<DeclarationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();
  
  // Controllers
  final _declarationNumberController = TextEditingController();
  final _statementNumberController = TextEditingController();
  final _statementDateController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _invoiceDateController = TextEditingController();
  final _invoiceValueController = TextEditingController();
  final _exchangeRateController = TextEditingController(text: '1250');
  final _containerNumberController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Dropdown values
  String? _selectedClientId;
  String? _selectedTraderId;
  String? _selectedSupplierId;
  String _selectedStatementType = 'استيراد';
  String _selectedCustomsCenter = 'ميناء عدن';
  String _selectedOriginCountry = 'اليمن';
  String _selectedExportCountry = 'الصين';
  String _selectedTransportMethod = 'بحري';
  String _selectedCurrency = 'USD';
  
  // Lists for dropdowns
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _traders = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _statementTypes = ['استيراد', 'تصدير', 'ترانزيت', 'إعادة تصدير'];
  final List<String> _customsCenters = ['ميناء عدن', 'ميناء الحديدة', 'ميناء المكلا', 'ميناء المخا', 'منفذ الوديعة', 'منفذ شحن'];
  final List<String> _countries = ['اليمن', 'السعودية', 'الإمارات', 'الصين', 'الهند', 'تركيا', 'مصر', 'الأردن', 'عمان', 'الكويت'];
  final List<String> _transportMethods = ['بحري', 'جوي', 'بري'];
  final List<String> _currencies = ['USD', 'EUR', 'SAR', 'AED'];

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    final db = await _dbHelper.database;
    
    final clientsResult = await db.query('clients', where: 'is_archived = 0');
    final tradersResult = await db.query('traders');
    final suppliersResult = await db.query('suppliers');
    
    setState(() {
      _clients = clientsResult;
      _traders = tradersResult;
      _suppliers = suppliersResult;
      _isLoading = false;
    });
  }

  Future<void> _saveDeclaration() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      final id = widget.declarationId ?? _uuid.v4();
      
      final declarationData = {
        'id': id,
        'declaration_number': _declarationNumberController.text,
        'statement_number': _statementNumberController.text,
        'statement_date': _statementDateController.text,
        'statement_type': _selectedStatementType,
        'customs_center': _selectedCustomsCenter,
        'client_id': _selectedClientId,
        'trader_id': _selectedTraderId,
        'supplier_id': _selectedSupplierId,
        'origin_country': _selectedOriginCountry,
        'export_country': _selectedExportCountry,
        'transport_method': _selectedTransportMethod,
        'container_number': _containerNumberController.text,
        'invoice_number': _invoiceNumberController.text,
        'invoice_date': _invoiceDateController.text,
        'invoice_value_usd': double.tryParse(_invoiceValueController.text) ?? 0,
        'currency': _selectedCurrency,
        'exchange_rate': double.tryParse(_exchangeRateController.text) ?? 1250,
        'items_count': 0,
        'notes': _notesController.text,
        'status': 'draft',
        'created_at': now,
        'updated_at': now,
      };
      
      if (widget.declarationId != null) {
        await db.update('declarations', declarationData, where: 'id = ?', whereArgs: [widget.declarationId]);
      } else {
        await db.insert('declarations', declarationData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الإقرار بنجاح'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.declarationId != null ? 'تعديل إقرار' : 'إقرار جديد'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('معلومات الإقرار'),
                    const SizedBox(height: 12),
                    _buildTextField('رقم الإقرار', _declarationNumberController, required: true),
                    const SizedBox(height: 12),
                    _buildTextField('رقم البيان', _statementNumberController),
                    const SizedBox(height: 12),
                    _buildDateField('تاريخ البيان', _statementDateController),
                    const SizedBox(height: 12),
                    _buildDropdown('نوع البيان', _selectedStatementType, _statementTypes, (val) => setState(() => _selectedStatementType = val!)),
                    const SizedBox(height: 12),
                    _buildDropdown('المركز الجمركي', _selectedCustomsCenter, _customsCenters, (val) => setState(() => _selectedCustomsCenter = val!)),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('معلومات العميل والمستورد'),
                    const SizedBox(height: 12),
                    _buildClientDropdown(),
                    const SizedBox(height: 12),
                    _buildTraderDropdown(),
                    const SizedBox(height: 12),
                    _buildSupplierDropdown(),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('معلومات الشحن والفاتورة'),
                    const SizedBox(height: 12),
                    _buildDropdown('بلد المنشأ', _selectedOriginCountry, _countries, (val) => setState(() => _selectedOriginCountry = val!)),
                    const SizedBox(height: 12),
                    _buildDropdown('بلد التصدير', _selectedExportCountry, _countries, (val) => setState(() => _selectedExportCountry = val!)),
                    const SizedBox(height: 12),
                    _buildDropdown('وسيلة النقل', _selectedTransportMethod, _transportMethods, (val) => setState(() => _selectedTransportMethod = val!)),
                    const SizedBox(height: 12),
                    _buildTextField('رقم الحاوية / الشاحنة', _containerNumberController),
                    const SizedBox(height: 12),
                    _buildTextField('رقم الفاتورة', _invoiceNumberController),
                    const SizedBox(height: 12),
                    _buildDateField('تاريخ الفاتورة', _invoiceDateController),
                    const SizedBox(height: 12),
                    _buildTextField('قيمة الفاتورة (دولار)', _invoiceValueController, required: true, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _buildDropdown('العملة', _selectedCurrency, _currencies, (val) => setState(() => _selectedCurrency = val!)),
                    const SizedBox(height: 12),
                    _buildTextField('سعر الصرف', _exchangeRateController, keyboardType: TextInputType.number),
                    
                    const SizedBox(height: 24),
                    _buildTextField('ملاحظات', _notesController, maxLines: 3),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveDeclaration,
                        child: _isSaving
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(widget.declarationId != null ? 'تحديث الإقرار' : 'حفظ الإقرار', style: GoogleFonts.cairo(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
      ),
      validator: required ? (value) => (value == null || value.isEmpty) ? 'هذا الحقل مطلوب' : null : null,
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          controller.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      },
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildClientDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedClientId,
      decoration: const InputDecoration(labelText: 'العميل *'),
      items: _clients.map((client) {
        return DropdownMenuItem(
          value: client['id'] as String,
          child: Text(client['name'] as String),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedClientId = val),
      validator: (value) => value == null ? 'العميل مطلوب' : null,
    );
  }

  Widget _buildTraderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedTraderId,
      decoration: const InputDecoration(labelText: 'المستورد'),
      items: [
        const DropdownMenuItem(value: null, child: Text('غير محدد')),
        ..._traders.map((trader) {
          return DropdownMenuItem(
            value: trader['id'] as String,
            child: Text(trader['name'] as String),
          );
        }),
      ],
      onChanged: (val) => setState(() => _selectedTraderId = val),
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSupplierId,
      decoration: const InputDecoration(labelText: 'المورد'),
      items: [
        const DropdownMenuItem(value: null, child: Text('غير محدد')),
        ..._suppliers.map((supplier) {
          return DropdownMenuItem(
            value: supplier['id'] as String,
            child: Text(supplier['name'] as String),
          );
        }),
      ],
      onChanged: (val) => setState(() => _selectedSupplierId = val),
    );
  }

  @override
  void dispose() {
    _declarationNumberController.dispose();
    _statementNumberController.dispose();
    _statementDateController.dispose();
    _invoiceNumberController.dispose();
    _invoiceDateController.dispose();
    _invoiceValueController.dispose();
    _exchangeRateController.dispose();
    _containerNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
