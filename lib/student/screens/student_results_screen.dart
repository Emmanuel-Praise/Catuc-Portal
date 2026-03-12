import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../theme/app_colors.dart';
import '../models/student_results_data.dart';
import '../models/student_session.dart';
import '../services/student_api_service.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';

class StudentResultsScreen extends StatefulWidget {
  final StudentSession user;

  const StudentResultsScreen({super.key, required this.user});

  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen> {
  late Future<StudentResultsData> _future;
  String? _year;
  String? _semester;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _future = const StudentApiService().fetchResults(
      studentId: widget.user.userId,
    );
  }

  Future<void> _load() async {
    setState(() {
      _future = const StudentApiService().fetchResults(
        studentId: widget.user.userId,
        year: _year,
        semester: _semester,
      );
    });
  }

  void _showReportDialog(dynamic error) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report an Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please describe what happened so we can fix it.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g. My results for this semester are missing...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                await const ReportService().submitReport(
                  userId: widget.user.userId,
                  role: 'student',
                  issueType: 'Student Results Error',
                  description: controller.text.trim(),
                  additionalData: {'error': error.toString()},
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Issue reported successfully. Thank you!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to report: $e')),
                );
              }
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  String _semesterLabel(String sem) {
    if (sem == '1') return 'First Semester';
    if (sem == '2') return 'Second Semester';
    return sem;
  }

  String _valueOrDash(String value) {
    final v = value.trim();
    return v.isEmpty ? '-' : v;
  }

  Future<void> _downloadResultsPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final data = await _future;
      if (!mounted) return;

      if (data.results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No results available to export.')),
        );
        return;
      }

      final doc = pw.Document();
      final now = DateTime.now();
      final semesterText = _semesterLabel(data.semester);

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CATHOLIC UNIVERSITY OF CAMEROON',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        'BAMENDA - CATUC PORTAL',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    width: 40,
                    height: 40,
                    color: PdfColors.blue900,
                    child: pw.Center(
                      child: pw.Text(
                        'R',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 20),
            ],
          ),
          footer: (context) => pw.Column(
            children: [
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Generated on ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'NOTE: This is a computerized result slip. For official use, please request a signed transcript.',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
          build: (context) => [
            pw.Text(
              'ACADEMIC RECORD: $semesterText ${data.year}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Student Info Section
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                color: PdfColors.grey50,
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('STUDENT NAME', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            pw.Text(widget.user.fullName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('MATRICULE / ID', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            pw.Text(widget.user.studentNumber ?? '-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Performance Table
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: [
                'CODE',
                'COURSE TITLE',
                'CR',
                'TOTAL',
                'GRADE',
                'STATUS',
              ],
              columnWidths: {
                0: const pw.FixedColumnWidth(60),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(30),
                3: const pw.FixedColumnWidth(45),
                4: const pw.FixedColumnWidth(40),
                5: const pw.FixedColumnWidth(50),
              },
              data: data.results
                  .map(
                    (r) => [
                      r.courseCode,
                      r.courseName,
                      '${r.credits}',
                      _valueOrDash(r.total),
                      _valueOrDash(r.grade),
                      _valueOrDash(r.status),
                    ],
                  )
                  .toList(),
            ),
            
            pw.SizedBox(height: 24),
            
            // Summary Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('TOTAL CREDITS ATTEMPTED: ', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('${data.creditsUsed}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('SEMESTER GPA: ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            data.sgpa == null ? 'PENDING' : '${data.sgpa!.toStringAsFixed(2)} / 4.00',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final filename =
          'results_${widget.user.studentNumber ?? widget.user.userId}_${data.year}_S${data.semester}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  List<Color> _getGradeColors(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return [AppColors.green, AppColors.green.withOpacity(0.8)];
      case 'B':
        return [AppColors.blue, AppColors.blue.withOpacity(0.8)];
      case 'C':
        return [AppColors.orange, AppColors.orange.withOpacity(0.8)];
      case 'D':
        return [
          AppColors.orange.withOpacity(0.8),
          AppColors.orange.withOpacity(0.6),
        ];
      case 'F':
        return [AppColors.red, AppColors.red.withOpacity(0.8)];
      default:
        return [Colors.grey, Colors.grey.withOpacity(0.8)];
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(179)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: _isExporting ? null : _downloadResultsPdf,
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: FutureBuilder<StudentResultsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorWidget(
              error: snapshot.error,
              onRetry: _load,
              onReport: () => _showReportDialog(snapshot.error),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No result data'));
          }

          final years = data.options.map((e) => e.year).toSet().toList();
          _year ??= data.year.isNotEmpty
              ? data.year
              : (years.isNotEmpty ? years.first : null);
          _semester ??= data.semester.isNotEmpty ? data.semester : '1';

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withAlpha(13), // 0.05 opacity
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.filter_list, color: AppColors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Filter Results',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.blue,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 620;
                            final sessionField =
                                DropdownButtonFormField<String>(
                                  key: ValueKey('year-${_year ?? ''}'),
                                  initialValue: _year,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Session',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.blue.withOpacity(0.05),
                                  ),
                                  items: years
                                      .map(
                                        (y) => DropdownMenuItem(
                                          value: y,
                                          child: Text(y),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    _year = v;
                                    _load();
                                  },
                                );

                            final semesterField =
                                DropdownButtonFormField<String>(
                                  key: ValueKey('sem-${_semester ?? ''}'),
                                  initialValue: _semester,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Semester',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.blue.withOpacity(0.05),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: '1',
                                      child: Text('First Semester'),
                                    ),
                                    DropdownMenuItem(
                                      value: '2',
                                      child: Text('Second Semester'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    _semester = v;
                                    _load();
                                  },
                                );

                            if (compact) {
                              return Column(
                                children: [
                                  sessionField,
                                  const SizedBox(height: 12),
                                  semesterField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: sessionField),
                                const SizedBox(width: 12),
                                Expanded(child: semesterField),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: AppColors.blueGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blue.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.assessment_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Semester GPA',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Credits used: ${data.creditsUsed}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            data.sgpa == null
                                ? 'Pending'
                                : '${data.sgpa!.toStringAsFixed(2)} / 4.00',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...data.results.map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _getGradeColors(r.grade),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).shadowColor.withAlpha(26), // 0.1 opacity
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ExpansionTile(
                      backgroundColor: Colors.transparent,
                      collapsedBackgroundColor: Colors.transparent,
                      title: Text(
                        r.courseCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        r.courseName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          r.grade,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildDetailRow(
                                'Credits',
                                '${r.credits}',
                                Icons.school,
                              ),
                              _buildDetailRow(
                                'Attendance',
                                r.attendance,
                                Icons.check_circle,
                              ),
                              _buildDetailRow('CA', r.ca, Icons.assignment),
                              _buildDetailRow(
                                'Practicals',
                                r.practicals,
                                Icons.science,
                              ),
                              _buildDetailRow('Exam', r.exam, Icons.quiz),
                              _buildDetailRow('Total', r.total, Icons.grade),
                              _buildDetailRow('Status', r.status, Icons.info),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (data.results.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('No results found'),
                      subtitle: Text('Try a different session/semester.'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
