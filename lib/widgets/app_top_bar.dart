import 'package:flutter/material.dart';

import '../screens/profile/profile_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'report_photo.dart';

/// TopBar standar SiFasilitas untuk seluruh halaman utama dan fitur
/// (di luar halaman autentikasi, onboarding, dan splash screen).
///
/// Struktur tiga bagian konsisten:
/// - Kiri atas: logo SiFasilitas polos di atas latar putih
/// - Tengah: nama halaman yang sedang diakses
/// - Ujung kanan: tombol profil pengguna (serta aksi tambahan opsional)
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.profileUid,
    this.userName,
    this.photoUrl,
    this.isProfileActive = false,
    this.onProfileTap,
    this.extraActions = const <Widget>[],
  });

  final String title;
  final String? profileUid;
  final String? userName;
  final String? photoUrl;
  final bool isProfileActive;
  final VoidCallback? onProfileTap;
  final List<Widget> extraActions;

  static const double barHeight = 60;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  static String? _initials(String? name) {
    if (name == null) return null;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return null;
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final VoidCallback? resolvedProfileTap = isProfileActive
        ? null
        : onProfileTap ??
              (profileUid == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          uid: profileUid!,
                          userName: userName,
                        ),
                      ),
                    ));

    return AppBar(
      toolbarHeight: barHeight,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      automaticallyImplyLeading: false,
      centerTitle: true,
      shape: const Border(
        bottom: BorderSide(color: AppColors.border, width: 1),
      ),
      leadingWidth: 60,
      leading: const Padding(
        padding: EdgeInsets.only(left: AppSpacing.md),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _TopBarLogo(),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        ...extraActions,
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: Center(
            child: _ProfileActionButton(
              initials: _initials(userName),
              photoUrl: photoUrl,
              isActive: isProfileActive,
              onTap: resolvedProfileTap,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tombol kembali terpisah di bawah logo TopBar (bukan di dalam TopBar),
/// sejajar vertikal dengan posisi logo di kiri atas.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(ModalRoute.of(context)?.canPop ?? false)) {
      return const SizedBox.shrink();
    }
    return Container(
      width: 42,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: BackButton(
        color: AppColors.ink,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          iconSize: 18,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _TopBarLogo extends StatelessWidget {
  const _TopBarLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Center(
        child: Transform.scale(
          scale: 1.9,
          child: Image.asset(
            'assets/images/Sifasilitas.png',
            width: 42,
            height: 42,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.apartment_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.initials,
    required this.photoUrl,
    required this.isActive,
    required this.onTap,
  });

  final String? initials;
  final String? photoUrl;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fallback = initials != null
        ? Text(
            initials!,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              letterSpacing: 0.2,
            ),
          )
        : const Icon(
            Icons.person_rounded,
            size: 20,
            color: AppColors.primaryDark,
          );
    final trimmedPhoto = photoUrl?.trim();
    final hasPhoto = trimmedPhoto != null && trimmedPhoto.isNotEmpty;

    return Tooltip(
      message: isActive ? 'Profil Akun (Aktif)' : 'Profil Akun',
      child: Semantics(
        button: true,
        label: 'Profil',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.highlightBorder, width: 1.2),
              ),
              child: ClipOval(
                child: Center(
                  child: hasPhoto
                      ? ReportPhoto(
                          ref: trimmedPhoto,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorWidget: Center(child: fallback),
                        )
                      : fallback,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
