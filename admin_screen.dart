import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/vehicle_model.dart';
import '../utils/constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'vehicle_detail_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;
  String _userSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _adminUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  // ── ADD VEHICLE BOTTOM SHEET ──────────────────────────────────────────────
  void _showAddVehicleDialog() {
    final vehicleNumberController = TextEditingController();
    final callNumberController = TextEditingController();
    final whatsappNumberController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_circle_outline,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text("Add Vehicle",
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text("A QR sticker will be generated for your vehicle",
                      style: TextStyle(fontSize: 13, color: AppColors.textLight)),
                  const SizedBox(height: 24),
                  CustomTextField(
                    hint: AppStrings.vehicleNumber,
                    controller: vehicleNumberController,
                    prefixIcon: Icons.confirmation_number_outlined,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? "Enter vehicle number" : null,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    hint: AppStrings.callNumber,
                    controller: callNumberController,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? "Enter call number" : null,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    hint: AppStrings.whatsappNumber,
                    controller: whatsappNumberController,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.message_outlined,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: "Add Vehicle & Generate QR",
                    isLoading: isLoading,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      setModal(() => isLoading = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);
                      try {
                        await _firestoreService.addVehicle(
                          userId: _adminUid,
                          vehicleNumber: vehicleNumberController.text,
                          callNumber: callNumberController.text,
                          whatsappNumber: whatsappNumberController.text,
                        );
                        if (mounted) {
                          nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text("Vehicle added! QR code generated."),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } finally {
                        setModal(() => isLoading = false);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteVehicle(VehicleModel vehicle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Vehicle",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            "Delete ${vehicle.vehicleNumber}? Its QR code will be deactivated."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel",
                  style: TextStyle(color: AppColors.textLight))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestoreService.deleteVehicle(vehicle.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Vehicle deleted"),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text("Delete",
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── USER ACTION DIALOGS ───────────────────────────────────────────────────
  void _showUserActions(Map<String, dynamic> user) {
    final uid = user["id"] as String;
    final name = user["name"] ?? user["email"] ?? "User";
    final isBlocked = user["isBlocked"] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text)),
              ),
              if (!isBlocked)
                _ActionTile(
                  icon: Icons.block,
                  color: Colors.orange,
                  label: "Block User",
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmAction(
                      title: "Block User",
                      message: "Block $name? They will not be able to login.",
                      confirmLabel: "Block",
                      confirmColor: Colors.orange,
                      onConfirm: () => _firestoreService.blockUser(uid),
                    );
                  },
                ),
              if (isBlocked)
                _ActionTile(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  label: "Unblock User",
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmAction(
                      title: "Unblock User",
                      message: "Allow $name to login again?",
                      confirmLabel: "Unblock",
                      onConfirm: () => _firestoreService.unblockUser(uid),
                    );
                  },
                ),
              _ActionTile(
                icon: Icons.admin_panel_settings,
                color: AppColors.primary,
                label: "Transfer Admin to $name",
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Text("Transfer Admin Authority",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      content: Text(
                          "You will lose admin access and $name will become the new admin. You will be redirected to the owner dashboard. This cannot be undone easily.",
                          style: const TextStyle(
                              color: AppColors.textLight, height: 1.5)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: const Text("Cancel",
                                style:
                                    TextStyle(color: AppColors.textLight))),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(dCtx);
                            try {
                              await _firestoreService.transferAdmin(
                                  _adminUid, uid);
                              // Role changed in Firestore — navigate to
                              // DashboardScreen since we're now an owner
                              if (mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const DashboardScreen()),
                                  (_) => false,
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text("Transfer failed: $e"),
                                      backgroundColor: AppColors.error,
                                      behavior:
                                          SnackBarBehavior.floating),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Transfer"),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _ActionTile(
                icon: Icons.delete_forever,
                color: AppColors.error,
                label: "Delete User",
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmAction(
                    title: "Delete User",
                    message:
                        "Permanently delete $name and all their vehicles?",
                    confirmLabel: "Delete",
                    confirmColor: AppColors.error,
                    onConfirm: () => _firestoreService.deleteUser(uid),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAction({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    Color? confirmColor,
    String confirmLabel = "Confirm",
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message,
            style: const TextStyle(color: AppColors.textLight, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel",
                  style: TextStyle(color: AppColors.textLight))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(gradient: AppGradients.primary),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.admin_panel_settings,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Admin Panel",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            Text("SecurePark Management",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          onPressed: _logout,
                        ),
                      ],
                    ),
                  ),
                  // Stats row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Row(
                      children: [
                        _StatCard(
                          stream: _firestoreService
                              .getAllUsers()
                              .map((u) => u.length),
                          label: "Total Users",
                          icon: Icons.people_alt_outlined,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          stream: _firestoreService
                              .getAllVehicles()
                              .map((v) => v.length),
                          label: "All Vehicles",
                          icon: Icons.directions_car_outlined,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          stream: _firestoreService.getAllUsers().map((u) =>
                              u.where((x) => x["isBlocked"] == true).length),
                          label: "Blocked",
                          icon: Icons.block_outlined,
                          iconColor: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(icon: Icon(Icons.directions_car), text: "My Vehicles"),
                      Tab(icon: Icon(Icons.people), text: "Users"),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1 ── Admin's own vehicles
                _MyVehiclesTab(
                  firestoreService: _firestoreService,
                  adminUid: _adminUid,
                  onAdd: _showAddVehicleDialog,
                  onDelete: _confirmDeleteVehicle,
                ),
                // TAB 2 ── All users
                _UsersTab(
                  firestoreService: _firestoreService,
                  searchQuery: _userSearch,
                  onSearchChanged: (v) => setState(() => _userSearch = v),
                  adminUid: _adminUid,
                  onUserTap: _showUserActions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MY VEHICLES TAB ──────────────────────────────────────────────────────────
class _MyVehiclesTab extends StatelessWidget {
  final FirestoreService firestoreService;
  final String adminUid;
  final VoidCallback onAdd;
  final void Function(VehicleModel) onDelete;

  const _MyVehiclesTab({
    required this.firestoreService,
    required this.adminUid,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VehicleModel>>(
      stream: firestoreService.getUserVehicles(adminUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final vehicles = snap.data ?? [];
        return Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text("${vehicles.length} Vehicle${vehicles.length == 1 ? "" : "s"}",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text("Add",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: vehicles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car,
                              size: 60,
                              color: AppColors.primary.withAlpha(120)),
                          const SizedBox(height: 16),
                          const Text("No vehicles added yet",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text)),
                          const SizedBox(height: 8),
                          const Text("Tap Add to register your first vehicle",
                              style: TextStyle(
                                  color: AppColors.textLight, fontSize: 13)),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: onAdd,
                            icon: const Icon(Icons.add),
                            label: const Text("Add Vehicle"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: vehicles.length,
                      itemBuilder: (_, i) {
                        final v = vehicles[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.primary,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.directions_car,
                                      color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(v.vehicleNumber,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: AppColors.text,
                                              letterSpacing: 1)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        const Icon(Icons.phone,
                                            size: 13,
                                            color: AppColors.textLight),
                                        const SizedBox(width: 4),
                                        Text(v.callNumber,
                                            style: const TextStyle(
                                                color: AppColors.textLight,
                                                fontSize: 13)),
                                      ]),
                                      if (v.whatsappNumber.isNotEmpty)
                                        Row(children: [
                                          const Icon(Icons.message,
                                              size: 13,
                                              color: AppColors.green),
                                          const SizedBox(width: 4),
                                          Text(v.whatsappNumber,
                                              style: const TextStyle(
                                                  color: AppColors.green,
                                                  fontSize: 13)),
                                        ]),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              VehicleDetailScreen(vehicle: v),
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withAlpha(25),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.qr_code,
                                                size: 14,
                                                color: AppColors.primary),
                                            SizedBox(width: 4),
                                            Text("QR",
                                                style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () => onDelete(v),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withAlpha(25),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                            Icons.delete_outline,
                                            color: AppColors.error,
                                            size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─── USERS TAB ────────────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final FirestoreService firestoreService;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String adminUid;
  final void Function(Map<String, dynamic>) onUserTap;

  const _UsersTab({
    required this.firestoreService,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.adminUid,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: "Search users by name or email…",
              hintStyle: const TextStyle(color: AppColors.textLight),
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.primary),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 16),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestoreService.getAllUsers(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary));
              }
              final allUsers = snap.data ?? [];
              final users = searchQuery.isEmpty
                  ? allUsers
                  : allUsers.where((u) {
                      final q = searchQuery.toLowerCase();
                      return (u["name"] ?? "")
                              .toString()
                              .toLowerCase()
                              .contains(q) ||
                          (u["email"] ?? "")
                              .toString()
                              .toLowerCase()
                              .contains(q);
                    }).toList();

              if (users.isEmpty) {
                return const Center(
                    child: Text("No users found",
                        style: TextStyle(color: AppColors.textLight)));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: users.length,
                itemBuilder: (_, i) {
                  final u = users[i];
                  final uid = u["id"] as String;
                  final isBlocked = u["isBlocked"] == true;
                  final isAdmin = u["role"] == "admin";
                  final isMe = uid == adminUid;

                  // Fetch vehicles count for this user
                  return _UserRow(
                    user: u,
                    isMe: isMe,
                    isAdmin: isAdmin,
                    isBlocked: isBlocked,
                    vehicleStream: firestoreService
                        .getUserVehicles(uid)
                        .map((v) => v.length),
                    onTap: isMe ? null : () => onUserTap(u),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── USER ROW ────────────────────────────────────────────────────────────────
class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isMe;
  final bool isAdmin;
  final bool isBlocked;
  final Stream<int> vehicleStream;
  final VoidCallback? onTap;

  const _UserRow({
    required this.user,
    required this.isMe,
    required this.isAdmin,
    required this.isBlocked,
    required this.vehicleStream,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = user["name"] ?? "No name";
    final email = user["email"] ?? "";
    final initial =
        name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : "?";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isBlocked
            ? Border.all(color: AppColors.error.withAlpha(100))
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    isAdmin ? AppColors.primary : AppColors.secondary,
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.text),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isAdmin) _Badge("ADMIN", AppColors.primary),
                        if (isBlocked) _Badge("BLOCKED", AppColors.error),
                        if (isMe) _Badge("YOU", AppColors.success),
                      ],
                    ),
                    Text(email,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                    StreamBuilder<int>(
                      stream: vehicleStream,
                      builder: (_, snap) => Text(
                        "${snap.data ?? 0} vehicle${(snap.data ?? 0) == 1 ? "" : "s"}",
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMe)
                const Icon(Icons.chevron_right,
                    color: AppColors.textLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── STAT CARD ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final Stream<int> stream;
  final String label;
  final IconData icon;
  final Color? iconColor;

  const _StatCard({
    required this.stream,
    required this.label,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(38),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor ?? Colors.white, size: 20),
            const SizedBox(height: 4),
            StreamBuilder<int>(
              stream: stream,
              builder: (_, snap) => Text(
                "${snap.data ?? 0}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── ACTION TILE ─────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ─── BADGE ────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color)),
    );
  }
}
