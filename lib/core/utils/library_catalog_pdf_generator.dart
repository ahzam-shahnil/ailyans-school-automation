import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart' show ReportTheme;

/// Generates an A4 landscape Library Books Catalog PDF report.
class LibraryCatalogPdfGenerator {
  LibraryCatalogPdfGenerator._();

  /// Generates the complete PDF document as bytes.
  static Future<Uint8List> generate({
    required List<Map<String, dynamic>> books,
    required String branchName,
    required String branchAddress,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final italicFont = pw.Font.helveticaOblique();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          branchName: branchName,
          branchAddress: branchAddress,
          totalCount: books.length,
          boldFont: boldFont,
          regularFont: regularFont,
        ),
        footer: (context) => _buildFooter(
          context: context,
          regularFont: regularFont,
          italicFont: italicFont,
        ),
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildTable(
            books: books,
            boldFont: boldFont,
            regularFont: regularFont,
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader({
    required String branchName,
    required String branchAddress,
    required int totalCount,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          branchName.isNotEmpty ? branchName.toUpperCase() : 'SCHOOL AUTOMATION',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 14,
            color: ReportTheme.primaryColor,
          ),
          textAlign: pw.TextAlign.center,
        ),
        if (branchAddress.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            branchAddress,
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 8.5,
              color: ReportTheme.secondaryColor,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: const pw.BoxDecoration(
            color: ReportTheme.bannerBgColor,
            border: pw.Border(
              top: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
              bottom: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'LIBRARY BOOKS CATALOG',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: ReportTheme.primaryColor,
                ),
              ),
              pw.Text(
                'Total Books: $totalCount',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 9,
                  color: ReportTheme.secondaryColor,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildFooter({
    required pw.Context context,
    required pw.Font regularFont,
    required pw.Font italicFont,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: ReportTheme.borderRuleColor, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on: ${ReportTheme.formatDate(DateTime.now())}',
            style: pw.TextStyle(
              font: italicFont,
              fontSize: 7.5,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 7.5,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTable({
    required List<Map<String, dynamic>> books,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    const headers = [
      'Book ID',
      'Title',
      'Author',
      'Publisher',
      'Category',
      'Price',
      'Status',
    ];

    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(55),
        1: pw.FlexColumnWidth(3.0),
        2: pw.FlexColumnWidth(2.0),
        3: pw.FlexColumnWidth(2.0),
        4: pw.FlexColumnWidth(1.8),
        5: pw.FixedColumnWidth(65),
        6: pw.FixedColumnWidth(60),
      },
      border: pw.TableBorder.all(
        color: ReportTheme.borderRuleColor,
        width: 0.5,
      ),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: ReportTheme.tableHeaderBg),
          children: headers.map((h) {
            final isRight = h == 'Price';
            final isCenter = h == 'Book ID' || h == 'Status';
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              alignment: isRight
                  ? pw.Alignment.centerRight
                  : (isCenter ? pw.Alignment.center : pw.Alignment.centerLeft),
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 8.5,
                  color: PdfColors.white,
                ),
              ),
            );
          }).toList(),
        ),

        // Data Rows
        ...books.asMap().entries.map((entry) {
          final index = entry.key;
          final b = entry.value;

          final bookId =
              (b['bookId'] ?? b['BookID'] ?? b['id'] ?? '').toString();
          final title =
              (b['bookName'] ?? b['BookName'] ?? b['title'] ?? '—').toString();
          final author =
              (b['bAuthor'] ?? b['BAuthor'] ?? b['author'] ?? '—').toString();
          final publisher =
              (b['pulishedBy'] ?? b['PulishedBy'] ?? b['publisher'] ?? '—')
                  .toString();
          final category =
              (b['categoryName'] ?? b['CategoryName'] ?? b['category'] ?? 'General')
                  .toString();
          final priceVal = b['bookPrice'] ?? b['BookPrice'] ?? b['price'];
          final priceStr = priceVal != null ? 'Rs. $priceVal' : '—';
          final status = (b['status'] ?? b['Status'] ?? 'Available').toString();

          final isAlt = index.isOdd;
          final rowBg = isAlt ? ReportTheme.tableRowAltBg : PdfColors.white;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  bookId.isNotEmpty ? '#$bookId' : '—',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  title,
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  author,
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  publisher,
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  category,
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  priceStr,
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  status,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 7.5,
                    color: status.toLowerCase() == 'issued'
                        ? ReportTheme.dangerTextColor
                        : ReportTheme.successTextColor,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}
