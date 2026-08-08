import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PdfGenerator {
  static final currencyFormatter = NumberFormat('#,##0.00');
  static final dateFormatter = DateFormat('yyyy/MM/dd');

  static Future<File> generateDeclarationReport(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader('تقرير الإقرارات الجمركية'),
          pw.SizedBox(height: 10),
          _buildSummaryTable(data['summary'] as Map<String, dynamic>),
          pw.SizedBox(height: 20),
          pw.Header(text: 'قائمة الإقرارات', level: 1),
          _buildDeclarationsTable(data['declarations'] as List<Map<String, dynamic>>),
        ],
      ),
    );
    
    return _saveAndGetFile(pdf, 'تقرير_الإقرارات.pdf');
  }

  static Future<File> generateClientStatement(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader('كشف حساب عميل'),
          pw.SizedBox(height: 10),
          pw.Text('العميل: ${data['client_name'] ?? ''}', style: const pw.TextStyle(fontSize: 16)),
          pw.Text('الرصيد الحالي: ${currencyFormatter.format(data['balance'] ?? 0)} ر.ي', style: pw.TextStyle(fontSize: 14, color: PdfColors.blue)),
          pw.SizedBox(height: 20),
          pw.Header(text: 'الحركات', level: 1),
          _buildTransactionsTable(data['transactions'] as List<Map<String, dynamic>>),
        ],
      ),
    );
    
    return _saveAndGetFile(pdf, 'كشف_حساب_${data['client_name']}.pdf');
  }

  static Future<File> generateFinancialReport(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader('التقرير المالي'),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatBox('الإيرادات', data['total_revenues'] ?? 0, PdfColors.green),
              _buildStatBox('المصروفات', data['total_expenses'] ?? 0, PdfColors.red),
              _buildStatBox('الأرباح', (data['total_revenues'] ?? 0) - (data['total_expenses'] ?? 0), PdfColors.blue),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Header(text: 'تفاصيل الإيرادات', level: 1),
          _buildRevenuesTable(data['revenues'] as List<Map<String, dynamic>>),
          pw.SizedBox(height: 20),
          pw.Header(text: 'تفاصيل المصروفات', level: 1),
          _buildExpensesTable(data['expenses'] as List<Map<String, dynamic>>),
        ],
      ),
    );
    
    return _saveAndGetFile(pdf, 'التقرير_المالي.pdf');
  }

  static Future<File> generateFundReport(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader('تقرير الصندوق'),
          pw.SizedBox(height: 10),
          pw.Text('التاريخ: ${data['date'] ?? ''}', style: const pw.TextStyle(fontSize: 14)),
          pw.Text('الرصيد الافتتاحي: ${currencyFormatter.format(data['opening_balance'] ?? 0)} ر.ي'),
          pw.Text('الرصيد الختامي: ${currencyFormatter.format(data['closing_balance'] ?? 0)} ر.ي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Header(text: 'الحركات', level: 1),
          _buildFundTransactionsTable(data['transactions'] as List<Map<String, dynamic>>),
        ],
      ),
    );
    
    return _saveAndGetFile(pdf, 'تقرير_الصندوق.pdf');
  }

  static pw.Widget _buildHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text(dateFormatter.format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static pw.Widget _buildStatBox(String label, double value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(currencyFormatter.format(value), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryTable(Map<String, dynamic> summary) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['البيان', 'القيمة'],
      data: [
        ['عدد الإقرارات', '${summary['count'] ?? 0}'],
        ['الإقرارات المنجزة', '${summary['completed'] ?? 0}'],
        ['الإقرارات الجارية', '${summary['processing'] ?? 0}'],
        ['إجمالي قيمة الفواتير', '${currencyFormatter.format(summary['total_value'] ?? 0)} \$'],
      ],
    );
  }

  static pw.Widget _buildDeclarationsTable(List<Map<String, dynamic>> declarations) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['رقم الإقرار', 'العميل', 'قيمة الفاتورة', 'الحالة', 'التاريخ'],
      data: declarations.map((d) => [
        d['declaration_number'] ?? '',
        d['client_name'] ?? '',
        '${currencyFormatter.format(d['invoice_value_usd'] ?? 0)} \$',
        d['status'] ?? '',
        d['statement_date'] ?? '',
      ]).toList(),
    );
  }

  static pw.Widget _buildTransactionsTable(List<Map<String, dynamic>> transactions) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['التاريخ', 'البيان', 'مدين', 'دائن', 'الرصيد'],
      data: transactions.map((t) => [
        t['date'] ?? '',
        t['description'] ?? '',
        t['debit']?.toString() ?? '',
        t['credit']?.toString() ?? '',
        t['balance']?.toString() ?? '',
      ]).toList(),
    );
  }

  static pw.Widget _buildRevenuesTable(List<Map<String, dynamic>> revenues) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['التاريخ', 'الفئة', 'المصدر', 'المبلغ'],
      data: revenues.map((r) => [
        r['revenue_date']?.toString().substring(0, 10) ?? '',
        r['category'] ?? '',
        r['source'] ?? '',
        '${currencyFormatter.format(r['amount'] ?? 0)} ر.ي',
      ]).toList(),
    );
  }

  static pw.Widget _buildExpensesTable(List<Map<String, dynamic>> expenses) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['التاريخ', 'الفئة', 'الوصف', 'المبلغ'],
      data: expenses.map((e) => [
        e['expense_date']?.toString().substring(0, 10) ?? '',
        e['category'] ?? '',
        e['description'] ?? '',
        '${currencyFormatter.format(e['amount'] ?? 0)} ر.ي',
      ]).toList(),
    );
  }

  static pw.Widget _buildFundTransactionsTable(List<Map<String, dynamic>> transactions) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: ['التاريخ', 'النوع', 'البيان', 'المبلغ'],
      data: transactions.map((t) => [
        t['transaction_date']?.toString().substring(0, 10) ?? '',
        t['type'] == 'income' ? 'قبض' : 'صرف',
        t['description'] ?? '',
        '${currencyFormatter.format(t['amount'] ?? 0)} ر.ي',
      ]).toList(),
    );
  }

  static Future<File> _saveAndGetFile(pw.Document pdf, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> sharePdf(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'تقرير');
  }

  static Future<void> printPdf(File file) async {
    await Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
  }
}
