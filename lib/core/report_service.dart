import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'alarm_service.dart';
import 'app_state.dart';
import 'auth_service.dart';
import 'settings_store.dart';
import 'vitals_store.dart';

/// Builds a PDF report (patient data, current readings, statistics and the
/// alarm log) and opens the share / print sheet.
class ReportService {
  ReportService._();

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _dateTime(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)} '
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

  static Future<void> shareReport(Duration range, String rangeLabel) async {
    final now = DateTime.now();
    final settings = SettingsStore.instance;
    final alarms = AlarmService.instance;
    final p = patientProfile;
    final current = VitalsStore.instance.vitals.value;
    final samples = VitalsStore.instance.samplesWithin(range);
    final from = now.subtract(range);
    final events = [
      for (final e in alarms.history)
        if (!e.time.isBefore(from)) e,
    ];

    // Fonts are downloaded the first time (needs internet). Without them the
    // report still works with the built-in font.
    pw.ThemeData? theme;
    try {
      theme = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansRegular(),
        bold: await PdfGoogleFonts.notoSansBold(),
      );
    } catch (_) {
      theme = null;
    }

    pw.Widget heading(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
      child: pw.Text(
        t,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );

    pw.Widget table(
      List<String> headers,
      List<List<String>> rows,
    ) => pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    );

    String temp(double? c) =>
        showDouble(c == null ? null : settings.toDisplayTemp(c), 1);

    // ----- Statistics for the chosen period -----
    final stats = <List<String>>[];
    for (final param in [
      AlarmParam.heartRate,
      AlarmParam.spo2,
      AlarmParam.respRate,
      AlarmParam.temperature,
      AlarmParam.bladder,
    ]) {
      final limit = alarms.limits[param]!;
      String fmt(double v) => AlarmService.formatNumber(param, v);
      String range0 = '-';
      if (limit.enabled) {
        range0 = param == AlarmParam.bladder
            ? '< ${fmt(limit.high)}'
            : '${fmt(limit.low)} - ${fmt(limit.high)}';
      }
      if (samples.isEmpty) {
        stats.add([
          AlarmService.labelOf(param),
          '-',
          '-',
          '-',
          range0,
          AlarmService.unitOf(param),
        ]);
        continue;
      }
      // Only the samples that have a reading for this parameter.
      final values = [
        for (final s in samples) ?AlarmService.valueOf(param, s.data),
      ];
      if (values.isEmpty) {
        stats.add([
          AlarmService.labelOf(param),
          '-',
          '-',
          '-',
          range0,
          AlarmService.unitOf(param),
        ]);
        continue;
      }
      final min = values.reduce((a, b) => a < b ? a : b);
      final max = values.reduce((a, b) => a > b ? a : b);
      final avg = values.reduce((a, b) => a + b) / values.length;
      stats.add([
        AlarmService.labelOf(param),
        fmt(min),
        fmt(avg),
        fmt(max),
        range0,
        AlarmService.unitOf(param),
      ]);
    }

    final doc = pw.Document(title: 'ARGUS patient report');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (ctx) => [
          pw.Text(
            'ARGUS - Patient Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated ${_dateTime(now)}  |  Period: last $rangeLabel',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(
            'Prepared by: ${currentUserName.value.isEmpty ? AuthService.email : currentUserName.value}'
            ' (${AuthService.email})',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          heading('Patient'),
          table(
            ['Field', 'Value'],
            [
              ['ID', p.id],
              ['Name', p.name],
              ['Age / Gender', '${p.age} / ${p.gender}'],
              ['Birth date', p.birthDate.isEmpty ? '-' : p.birthDate],
              ['Blood group', p.bloodGroup],
              ['Height / Weight', '${p.height} cm / ${p.weight} kg'],
              ['Room', p.room],
              ['Doctor', p.doctor],
              ['Chronic diseases', p.chronicDiseases],
              ['Allergies', p.allergies],
              ['Medications', p.medications],
              ['Emergency contact', p.emergencyContact],
              ['Notes', p.notes],
            ],
          ),
          heading('Current readings'),
          table(
            ['Heart rate', 'SpO2', 'Resp. rate', 'Temperature', 'Bladder'],
            [
              [
                '${showInt(current.hr)} BPM',
                '${showInt(current.spo2)} %',
                '${showInt(current.rr)} RPM',
                '${temp(current.temp)} ${settings.tempSymbol}',
                '${showDouble(current.bladderPercent, 0)} %',
              ],
            ],
          ),
          heading('Statistics (last $rangeLabel, ${samples.length} readings)'),
          table([
            'Parameter',
            'Min',
            'Average',
            'Max',
            'Alarm limits',
            'Unit',
          ], stats),
          heading('Alarm log (${events.length})'),
          if (events.isEmpty)
            pw.Text(
              'No alarms in this period.',
              style: const pw.TextStyle(fontSize: 10),
            )
          else
            table(
              ['Time', 'Parameter', 'Level', 'Message', 'Value'],
              [
                for (final e in events)
                  [
                    _dateTime(e.time),
                    e.label,
                    e.level.name.toUpperCase(),
                    e.message,
                    e.valueText,
                  ],
              ],
            ),
        ],
      ),
    );

    final bytes = await doc.save();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';
    await Printing.sharePdf(bytes: bytes, filename: 'argus_report_$stamp.pdf');
  }
}
