// lib/utils/payslip_pdf_generator.dart

import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/position_model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PayslipPdfGenerator {
  final Employee employee;
  final Department? department;
  final Position? position;
  final String payslipMonth;

  PayslipPdfGenerator({
    required this.employee,
    this.department,
    this.position,
    required this.payslipMonth,
  });

  Future<void> generateAndShowPayslip() async {
    final pdf = pw.Document();

    // --- [START] MODIFIED CODE ---
    // Use the PdfGoogleFonts helper to load fonts in a web-compatible way
    final font = await PdfGoogleFonts.sarabunRegular();
    final boldFont = await PdfGoogleFonts.sarabunBold();
    // --- [END] MODIFIED CODE ---

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: boldFont,
    );

    // Placeholder data for earnings and deductions
    final earnings = {
      'เงินเดือน (Salary)': employee.salary,
      'ค่าล่วงเวลา (Overtime)': 1500.00,
      'โบนัส (Bonus)': 500.00,
    };
    final deductions = {
      'ภาษีหัก ณ ที่จ่าย (Withholding Tax)': 500.00,
      'ประกันสังคม (Social Security)': 750.00,
      'กองทุนสำรองเลี้ยงชีพ (Provident Fund)': 750.00,
      'ขาดงาน (Absence)': 0.00,
      'มาสาย (Late)': 0.00,
    };

    final totalEarnings = earnings.values.reduce((a, b) => a + b);
    final totalDeductions = deductions.values.reduce((a, b) => a + b);
    final netSalary = totalEarnings - totalDeductions;
    final currencyFormat = NumberFormat("#,##0.00", "en_US");

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              pw.SizedBox(height: 20),
              _buildEmployeeInfo(),
              pw.Divider(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _buildTransactionTable('รายการเงินได้ (Earnings)', earnings, totalEarnings, currencyFormat)),
                  pw.SizedBox(width: 20),
                  pw.Expanded(child: _buildTransactionTable('รายการหัก (Deductions)', deductions, totalDeductions, currencyFormat)),
                ],
              ),
              pw.Divider(height: 20),
              _buildSummary(netSalary, currencyFormat),
              pw.Divider(height: 20),
              _buildFooter(),
              pw.Spacer(),
              _buildSignatureSection(),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final fileName = 'payslip_${employee.employeeId}_$payslipMonth.pdf';

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
    );
  }

  pw.Widget _buildHeader() {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text('ใบแจ้งเงินเดือน / PAYSLIP', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text('บริษัท วังเภสัชฟาร์มาซูติคอล จำกัด', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text('เลขที่ 23 ซอยพัฒโน ถนนอนุสรณ์อาจาร์ยทอง ตำบลหาดใหญ่ อำเภอหาดใหญ่ จังหวัดสงขลา 90110', style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildEmployeeInfo() {
    final positionNames = employee.positions.map((p) => p['name'] ?? '').join(', ');
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        _buildInfoTableRow('รหัสพนักงาน:', employee.employeeId, 'ชื่อ:', employee.fullName),
        _buildInfoTableRow('แผนก:', department?.name ?? 'N/A', 'ตำแหน่ง:', positionNames),
        _buildInfoTableRow('ประจำเดือน:', payslipMonth, '', ''),
      ],
    );
  }

  pw.TableRow _buildInfoTableRow(String label1, String value1, String label2, String value2) {
    return pw.TableRow(
      children: [
        pw.Text(label1, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(value1),
        pw.Text(label2, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(value2),
      ],
    );
  }

  pw.Widget _buildTransactionTable(String title, Map<String, num> items, num total, NumberFormat format) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        pw.SizedBox(height: 5),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            ...items.entries.map((entry) => pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(entry.key)),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(format.format(entry.value), textAlign: pw.TextAlign.right)),
              ],
            )),
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('รวม', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(format.format(total), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              ],
            )
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSummary(num netSalary, NumberFormat format) {
    const ytdEarnings = 150000.00;
    const ytdTax = 3000.00;
    const ytdSso = 4500.00;

    return pw.Table(
       columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(children: [
          pw.Text('รายรับสะสม:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(format.format(ytdEarnings)),
          pw.Text('ภาษีสะสม:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(format.format(ytdTax)),
        ]),
        pw.TableRow(children: [
          pw.Text('ประกันสังคมสะสม:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(format.format(ytdSso)),
          pw.Text('เงินได้สุทธิ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(format.format(netSalary), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ]),
      ]
    );
  }

  pw.Widget _buildFooter() {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        _buildInfoTableRow(
          'หมายเหตุ:', 
          'สลิปเงินเดือนฉบับนี้เป็นความลับ ไม่ควรเผยแพร่ให้พนักงานท่านอื่นทราบ', 
          'ชื่อ ธนาคาร (ถ้ามี):', 
          employee.bankAccount['bankName'] ?? 'N/A'
        ),
        _buildInfoTableRow(
          '', 
          '', 
          'เลขที่บัญชี (ถ้ามี):', 
          employee.bankAccount['accountNumber'] ?? 'N/A'
        ),
      ],
    );
  }

  pw.Widget _buildSignatureSection() {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.SizedBox(width: 150, child: pw.Divider()),
            pw.Text("ผู้รับเงิน (Recipient's Signature)"),
            pw.SizedBox(height: 10),
            pw.Text("พิมพ์โดย: ฝ่ายทรัพยากรบุคคล วังเภสัช", style: const pw.TextStyle(fontSize: 10)),
          ]
        ),
        pw.Column(
          children: [
            pw.SizedBox(width: 150, child: pw.Divider()),
            pw.Text("ฝ่ายทรัพยากรบุคคล (HR Department)"),
            pw.SizedBox(height: 10),
            pw.Text("ออกเอกสาร: ${dateFormat.format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10)),
          ]
        ),
      ]
    );
  }
}
