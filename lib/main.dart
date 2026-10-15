
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BarangayApp());
}

const Color navy = Color(0xFF12345A);
const Color blue = Color(0xFF246BCE);
const Color background = Color(0xFFF4F7FB);

class Appointment {
  final String id;
  final String name;
  final String service;
  final String date;
  final String time;
  final String contact;
  final String purpose;
  final String status;

  Appointment({
    required this.id,
    required this.name,
    required this.service,
    required this.date,
    required this.time,
    required this.contact,
    required this.purpose,
    this.status = 'Pending',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'service': service,
        'date': date,
        'time': time,
        'contact': contact,
        'purpose': purpose,
        'status': status,
      };

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      name: json['name'],
      service: json['service'],
      date: json['date'],
      time: json['time'],
      contact: json['contact'],
      purpose: json['purpose'],
      status: json['status'] ?? 'Pending',
    );
  }
}

class BarangayApp extends StatelessWidget {
  const BarangayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barangay Appointment',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5EAF2)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 0;
  bool loading = true;
  bool loadingNews = true;
  String search = '';
  List<Appointment> appointments = [];
  List<dynamic> announcements = [];
  String? newsError;

  final List<String> services = [
    'Barangay Clearance',
    'Certificate of Residency',
    'Certificate of Indigency',
    'Business Clearance',
    'Barangay ID',
    'Other Concern',
  ];

  @override
  void initState() {
    super.initState();
    loadAppointments();
    loadAnnouncements();
  }

  Future<void> loadAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('appointments') ?? '[]';

    try {
      final List<dynamic> data = jsonDecode(saved);
      appointments = data
          .map((item) => Appointment.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      appointments = [];
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'appointments',
      jsonEncode(appointments.map((a) => a.toJson()).toList()),
    );
  }

  Future<void> loadAnnouncements() async {
    setState(() {
      loadingNews = true;
      newsError = null;
    });

    try {
      final response = await http
          .get(Uri.parse(
              'https://jsonplaceholder.typicode.com/posts?_limit=5'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as List;

      if (!mounted) return;

      setState(() {
        announcements = data;
        loadingNews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingNews = false;
        newsError = 'Unable to load announcements. Check your internet.';
      });
    }
  }

  Future<void> addAppointment(Appointment appointment) async {
    setState(() => appointments.insert(0, appointment));
    await saveAppointments();
  }

  Future<void> deleteAppointment(Appointment appointment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text(
          'Delete the ${appointment.service} appointment for '
          '${appointment.date} at ${appointment.time}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep appointment'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        appointments.removeWhere((a) => a.id == appointment.id);
      });
      await saveAppointments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment deleted.')),
        );
      }
    }
  }

  Future<void> changeStatus(Appointment appointment) async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Update appointment status'),
        children: [
          for (final status in ['Pending', 'Approved', 'Rejected'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, status),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(status),
              ),
            ),
        ],
      ),
    );

    if (newStatus == null || !mounted) return;

    setState(() {
      final index = appointments.indexWhere((a) => a.id == appointment.id);
      if (index != -1) {
        final a = appointments[index];
        appointments[index] = Appointment(
          id: a.id,
          name: a.name,
          service: a.service,
          date: a.date,
          time: a.time,
          contact: a.contact,
          purpose: a.purpose,
          status: newStatus,
        );
      }
    });

    await saveAppointments();
  }

  Future<void> openBookingForm() async {
    final result = await Navigator.push<Appointment>(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(services: services),
      ),
    );

    if (result != null && mounted) {
      await addAppointment(result);
      setState(() => selectedTab = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      dashboard(),
      appointmentPage(),
      announcementPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Barangay Connect',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh announcements',
            onPressed: loadAnnouncements,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: pages[selectedTab],
          ),
        ),
      ),
      floatingActionButton: selectedTab == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: openBookingForm,
              backgroundColor: blue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Book Appointment'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'News',
          ),
        ],
      ),
    );
  }

  Widget dashboard() {
    final pending = appointments.where((a) => a.status == 'Pending').length;
    final approved = appointments.where((a) => a.status == 'Approved').length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [navy, blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_balance, color: Colors.white, size: 38),
              SizedBox(height: 18),
              Text(
                'Welcome to Barangay Connect',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your convenient way to schedule barangay services.',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionTitle(title: 'Appointment Overview'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Total',
                count: appointments.length,
                icon: Icons.event_note,
                color: blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                title: 'Pending',
                count: pending,
                icon: Icons.schedule,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                title: 'Approved',
                count: approved,
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionTitle(title: 'Available Services'),
        const SizedBox(height: 12),
        for (final service in services)
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEAF1FF),
                child: Icon(Icons.description_outlined, color: blue),
              ),
              title: Text(
                service,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: openBookingForm,
            ),
          ),
        const SizedBox(height: 20),
        const SectionTitle(title: 'Latest Announcements'),
        const SizedBox(height: 12),
        announcementContent(limit: 3),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget appointmentPage() {
    final filtered = appointments.where((a) {
      final query = search.toLowerCase();
      return a.name.toLowerCase().contains(query) ||
          a.service.toLowerCase().contains(query) ||
          a.status.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) => setState(() => search = value),
            decoration: const InputDecoration(
              hintText: 'Search appointments...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.calendar_month,
                      title: 'No appointments found',
                      message: 'Book an appointment to get started.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final appointment = filtered[index];

                        return AppointmentCard(
                          appointment: appointment,
                          onDelete: () => deleteAppointment(appointment),
                          onStatus: () => changeStatus(appointment),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget announcementPage() {
    return RefreshIndicator(
      onRefresh: loadAnnouncements,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionTitle(title: 'Community Announcements'),
          const SizedBox(height: 8),
          const Text(
            'Updates retrieved from an external API.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          announcementContent(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget announcementContent({int? limit}) {
    if (loadingNews) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (newsError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              Text(newsError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: loadAnnouncements,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final items = limit == null
        ? announcements
        : announcements.take(limit).toList();

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.campaign,
        title: 'No announcements',
        message: 'There are no updates available right now.',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final title = item['title'].toString();
        final body = item['body'].toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign, color: blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Community Update ${index + 1}',
                        style: const TextStyle(
                          color: blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title[0].toUpperCase() + title.substring(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(body),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BookingScreen extends StatefulWidget {
  final List<String> services;

  const BookingScreen({super.key, required this.services});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final contactController = TextEditingController();
  final purposeController = TextEditingController();

  String? selectedService;
  DateTime? selectedDate;
  String? selectedTime;

  final times = [
    '8:00 AM',
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
    '1:00 PM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
  ];

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    purposeController.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;

    if (selectedService == null ||
        selectedDate == null ||
        selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a service, date, and time.'),
        ),
      );
      return;
    }

    final date = selectedDate!;
    final formattedDate =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    Navigator.pop(
      context,
      Appointment(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        service: selectedService!,
        date: formattedDate,
        time: selectedTime!,
        contact: contactController.text.trim(),
        purpose: purposeController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book an Appointment')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.event_available, size: 54, color: blue),
                const SizedBox(height: 12),
                const Text(
                  'Appointment Request',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fill in your information to request a schedule.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const FieldLabel(text: 'Full Name'),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Enter your full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.trim().length < 3
                      ? 'Enter your complete name.'
                      : null,
                ),
                const SizedBox(height: 16),
                const FieldLabel(text: 'Contact Number'),
                TextFormField(
                  controller: contactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Enter your contact number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => v == null ||
                          v.trim().replaceAll(RegExp(r'\D'), '').length < 7
                      ? 'Enter a valid contact number.'
                      : null,
                ),
                const SizedBox(height: 16),
                const FieldLabel(text: 'Service'),
                DropdownButtonFormField<String>(
                  value: selectedService,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  hint: const Text('Choose a service'),
                  items: widget.services
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedService = value),
                  validator: (v) => v == null ? 'Select a service.' : null,
                ),
                const SizedBox(height: 16),
                const FieldLabel(text: 'Preferred Date'),
                OutlinedButton.icon(
                  onPressed: chooseDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    selectedDate == null
                        ? 'Choose date'
                        : '${selectedDate!.month.toString().padLeft(2, '0')}/'
                            '${selectedDate!.day.toString().padLeft(2, '0')}/'
                            '${selectedDate!.year}',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 16),
                const FieldLabel(text: 'Preferred Time'),
                DropdownButtonFormField<String>(
                  value: selectedTime,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  hint: const Text('Choose a time slot'),
                  items: times
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedTime = value),
                ),
                const SizedBox(height: 16),
                const FieldLabel(text: 'Purpose or Additional Details'),
                TextFormField(
                  controller: purposeController,
                  maxLines: 3,
                  maxLength: 250,
                  decoration: const InputDecoration(
                    hintText: 'Explain your request (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: submit,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Submit Appointment'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onDelete;
  final VoidCallback onStatus;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onDelete,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (appointment.status) {
      'Approved' => Colors.green,
      'Rejected' => Colors.red,
      _ => Colors.orange,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFEAF1FF),
                  child: Icon(Icons.event_note, color: blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    appointment.service,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'status') onStatus();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'status',
                      child: Text('Update status'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete appointment'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Resident: ${appointment.name}'),
            const SizedBox(height: 6),
            Text('Contact: ${appointment.contact}'),
            const SizedBox(height: 6),
            Text('Date: ${appointment.date} • ${appointment.time}'),
            if (appointment.purpose.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Purpose: ${appointment.purpose}'),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                appointment.status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: navy,
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, size: 52, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
