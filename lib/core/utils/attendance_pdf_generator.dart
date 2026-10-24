// ignore_for_file: public_member_api_docs
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/attendance_roster_row.dart';
import '../theme/app_theme_tokens.dart';

/// Data bundle passed to the institutional attendance roll-call PDF generator.
class AttendancePdfData {
  final String branchName;
  final String branchAddress;
  final String? branchPhone;
  final String? branchPrincipal;
  final String className;
  final String sectionName;
  final String teacherName;
  final String sessionYear;
  final DateTime attDate;
  final List<AttendanceRosterRow> roster;
  final int presentCount;
  final int absentCount;
  final int leaveCount;
  final int lateCount;
  final int totalCount;

  const AttendancePdfData({
    required this.branchName,
    required this.branchAddress,
    this.branchPhone,
    this.branchPrincipal,
    required this.className,
    required this.sectionName,
    required this.teacherName,
    required this.sessionYear,
    required this.attDate,
    required this.roster,
    required this.presentCount,
    required this.absentCount,
    required this.leaveCount,
    required this.lateCount,
    required this.totalCount,
  });
}

/// Generates the institutional A4 landscape attendance register PDF document.
Future<Uint8List> buildAttendancePdf(AttendancePdfData data) async {
  final doc = pw.Document(
    title: 'Attendance Register - ${data.className} ${data.sectionName}',
    author: data.branchName,
  );

  final baseFont = await PdfGoogleFonts.robotoRegular();
  final boldFont = await PdfGoogleFonts.robotoBold();

  final borderColor = PdfColor.fromHex('CBD5E1');
  final headerBgColor = PdfColor.fromHex('F1F5F9');
  final alternateRowColor = PdfColor.fromHex('F8FAFC');

  final dateFormatted =
      '${data.attDate.year.toString().padLeft(4, '0')}-${data.attDate.month.toString().padLeft(2, '0')}-${data.attDate.day.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
      build: (pw.Context context) {
        return [
          // 1. Institutional Header
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: borderColor, width: 1.5),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Crest badge
                pw.Container(
                  width: 44,
                  height: 44,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('1E3A8A'),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'AH',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      font: boldFont,
                      fontSize: 18,
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),

                // School Name & Address
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        data.branchName.toUpperCase(),
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 14,
                          color: PdfColor.fromHex('0F172A'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${data.branchAddress}${data.branchPhone != null && data.branchPhone!.isNotEmpty ? ' | Phone: ${data.branchPhone}' : ''}',
                        style: pw.TextStyle(
                          font: baseFont,
                          fontSize: 9,
                          color: PdfColor.fromHex('475569'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Report Title Badge
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('EEF2F6'),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                    border: pw.Border.all(color: borderColor, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'DAILY ATTENDANCE ROLL-CALL',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 10,
                          color: PdfColor.fromHex('1E293B'),
                        ),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Class: ${data.className} - ${data.sectionName} | Date: $dateFormatted',
                        style: pw.TextStyle(
                          font: baseFont,
                          fontSize: 8.5,
                          color: PdfColor.fromHex('64748B'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // 2. Metadata Strip
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('F8FAFC'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: borderColor, width: 0.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Academic Session: ${data.sessionYear}',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8.5,
                    color: PdfColor.fromHex('334155'),
                  ),
                ),
                pw.Text(
                  'Section Teacher: ${data.teacherName.isNotEmpty ? data.teacherName : "Unassigned"}',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8.5,
                    color: PdfColor.fromHex('334155'),
                  ),
                ),
                pw.Text(
                  'Generated: ${DateTime.now().toString().substring(0, 16)}',
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 8,
                    color: PdfColor.fromHex('64748B'),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // 3. Tabular Roster Grid
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontSize: 8.5,
              color: PdfColor.fromHex('1E293B'),
            ),
            headerDecoration: pw.BoxDecoration(color: headerBgColor),
            headerHeight: 22,
            cellHeight: 18,
            cellStyle: pw.TextStyle(
              font: baseFont,
              fontSize: 8,
              color: PdfColor.fromHex('0F172A'),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: pw.BoxDecoration(color: alternateRowColor),
            columnWidths: const {
              0: pw.FixedColumnWidth(42), // Roll
              1: pw.FixedColumnWidth(54), // Reg ID
              2: pw.FlexColumnWidth(2.8), // Student Name
              3: pw.FlexColumnWidth(2.6), // Father Name
              4: pw.FixedColumnWidth(64), // Status
              5: pw.FixedColumnWidth(58), // In
              6: pw.FixedColumnWidth(58), // Out
              7: pw.FlexColumnWidth(3.0), // Remarks
            },
            headers: [
              'Roll',
              'Reg ID',
              'Student Name',
              'Father Name',
              'Status',
              'In',
              'Out',
              'Remarks',
            ],
            data: data.roster.map((row) {
              return [
                row.rollNo.toString(),
                row.stuRegId.toString(),
                row.getNameDisplay(),
                row.fatherName,
                row.currentStatus,
                row.inTime ?? '-',
                row.outTime ?? '-',
                row.attRemarks ?? '',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 6),

          // 4. Summary Totals Bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: headerBgColor,
              border: pw.Border.all(color: borderColor, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SUMMARY HEADCOUNT:',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8.5,
                    color: PdfColor.fromHex('1E293B'),
                  ),
                ),
                pw.Text(
                  'Present: ${data.presentCount}',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8.5,
                    color: PdfColor.fromHex('15803D'),
                  ),
                ),
                pw.Text(
                  'Absent: ${data.absentCount}',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8.5,
                    color: PdfColor.fromHex('DC2626'),
                  ),
                ),
                pw.Text(
                  'Leave: ${data.leaveCount}',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8.5,
                    color: PdfColor.fromHex('D97706'),
                  ),
                ),
                pw.Text(
                  'Late: ${data.lateCount}',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8.5,
                    color: PdfColor.fromHex('2563EB'),
                  ),
                ),
                pw.Text(
                  'Total Enrolled: ${data.totalCount}',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8.5,
                    color: PdfColor.fromHex('0F172A'),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // 5. Signature Footer
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 180, height: 1, color: borderColor),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Prepared By (Class Teacher)',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 8,
                      color: PdfColor.fromHex('475569'),
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 180, height: 1, color: borderColor),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Verified By (Attendance Incharge)',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 8,
                      color: PdfColor.fromHex('475569'),
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 180, height: 1, color: borderColor),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Principal Signature & Stamp',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 8,
                      color: PdfColor.fromHex('475569'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ];
      },
    ),
  );

  return doc.save();
}

/// Displays the institutional print preview modal for attendance roll call.
void showAttendancePrintPreviewDialog(
  BuildContext context,
  AttendancePdfData data,
) {
  final printButtonKey = GlobalKey();

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        child: Container(
          width: 1180,
          height: 820,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: [
              // Dialog Action Header
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.borderDefault),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.print_outlined,
                      size: 20,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Attendance Roll Call - ${data.className} (${data.sectionName})',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),

                    // Share Button
                    OutlinedButton.icon(
                      onPressed: () async {
                        final bytes = await buildAttendancePdf(data);
                        final box =
                            printButtonKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        final bounds = box != null
                            ? box.localToGlobal(Offset.zero) & box.size
                            : const Rect.fromLTWH(0, 0, 100, 100);

                        await Printing.sharePdf(
                          bytes: bytes,
                          filename:
                              'attendance_roll_call_${data.className}_${data.sectionName}.pdf',
                          bounds: bounds,
                        );
                      },
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderDefault),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Print Button
                    ElevatedButton.icon(
                      key: printButtonKey,
                      onPressed: () async {
                        final bytes = await buildAttendancePdf(data);
                        await Printing.layoutPdf(
                          onLayout: (_) => bytes,
                          name:
                              'attendance_${data.className}_${data.sectionName}',
                        );
                      },
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print (Ctrl+P)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Close Button
                    Tooltip(
                      message: 'Close (Esc)',
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  ],
                ),
              ),

              // PDF Preview Body
              Expanded(
                child: PdfPreview(
                  build: (_) => buildAttendancePdf(data),
                  useActions: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  pdfFileName:
                      'attendance_${data.className}_${data.sectionName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
