import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'tariff_service.dart';

class PdfService {
  static Future<void> generateAndDownloadBill({
    required BillDetails billDetails,
    required String userName,
    required String address,
    required String stateName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('URJA BUDDY', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                  pw.Text('ELECTRICITY BILL', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Consumer Details
              pw.Text('Consumer Details:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Family Name: $userName', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Address: $address', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('State: $stateName', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Billing Period: Current Month', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 14)),
              
              pw.SizedBox(height: 30),

              // Usage Summary
              pw.Text('Usage & Slab Breakdown:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey400),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
                cellAlignment: pw.Alignment.centerLeft,
                data: <List<String>>[
                  <String>['Description', 'Units', 'Rate (₹)', 'Amount (₹)'],
                  <String>['Total Consumption', '${billDetails.totalUnits.toStringAsFixed(1)} kWh', '-', '-'],
                  if (billDetails.freeUnitsDeducted > 0)
                    <String>['Free Units Deducted', '${billDetails.freeUnitsDeducted.toStringAsFixed(1)} kWh', '₹0.00', '₹0.00'],
                  ...billDetails.slabs.map((s) => [
                    'Slab (Rate: ₹${s.rate.toStringAsFixed(2)})', 
                    s.units.toStringAsFixed(1), 
                    s.rate.toStringAsFixed(2), 
                    s.amount.toStringAsFixed(2)
                  ]),
                  <String>['Subtotal', '-', '-', '₹${billDetails.subtotal.toStringAsFixed(2)}'],
                  <String>['Fixed Charges', '-', '-', '₹${billDetails.fixedCharges.toStringAsFixed(2)}'],
                  <String>['Taxes (${billDetails.taxPercent}%)', '-', '-', '₹${billDetails.taxAmount.toStringAsFixed(2)}'],
                ],
              ),

              pw.SizedBox(height: 20),
              
              // Total
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total Payable: ₹${billDetails.totalPayable.toStringAsFixed(2)}', 
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)
                ),
              ),
              
              pw.SizedBox(height: 50),
              
              // Footer Message
              pw.Center(
                child: pw.Text('Thank you for using Urja Buddy! Together we can save energy and reduce our carbon footprint.', 
                  style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
              )
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Urja_Buddy_Bill_${userName.replaceAll(' ', '_')}.pdf');
  }
}
