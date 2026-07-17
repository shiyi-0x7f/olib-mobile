import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';

enum ShareStyle {
  museum,    // 极简留白风格
  magazine,  // 杂志卡片风格
  glass,     // 沉浸磨砂风格
}

/// A highly customizable book list sharing widget with multiple themes.
class ShareSnapshotWidget extends StatelessWidget {
  final List<Book> books;
  final String userName;
  final ShareStyle style;
  final String? customTitle;
  final String? customContent;
  final String? qrData;

  /// Maximum number of books displayed before truncation.
  static const int maxDisplay = 10;

  const ShareSnapshotWidget({
    super.key,
    required this.books,
    this.userName = 'Olib',
    this.style = ShareStyle.museum,
    this.customTitle,
    this.customContent,
    this.qrData,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case ShareStyle.museum:
        return _buildMuseumStyle(context);
      case ShareStyle.magazine:
        return _buildMagazineStyle(context);
      case ShareStyle.glass:
        return _buildGlassStyle(context);
    }
  }

  // ─── Style 1: Museum (极简留白) ───────────────────────────
  Widget _buildMuseumStyle(BuildContext context) {
    final displayBooks = _getDisplayBooks();
    final remaining = books.length - displayBooks.length;
    final dateStr = _getDateStr();

    return Container(
      width: 375,
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (customTitle?.isEmpty ?? true) ? 'READING LIST' : customTitle!,
                      style: const TextStyle(
                        fontFamily: 'Serif',
                        fontWeight: FontWeight.w900,
                        fontSize: 18, // increased for custom title
                        letterSpacing: 1.0,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateStr · $userName',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (customContent != null && customContent!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        customContent!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (qrData != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _buildQrCode(size: 48, color: Colors.black87),
                ),
            ],
          ),
          const SizedBox(height: 32),

          // Books
          ...displayBooks.map((book) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover with shadow
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.15),
                            offset: const Offset(4, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: _buildCover(book, width: 48, height: 72),
                    ),
                    const SizedBox(width: 20),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (book.author?.isNotEmpty == true)
                            Text(
                              book.author!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),

          // Footer
          if (remaining > 0)
            Center(
              child: Text(
                '... and $remaining more',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Style 2: Magazine (杂志卡片) ─────────────────────────
  Widget _buildMagazineStyle(BuildContext context) {
    final displayBooks = _getDisplayBooks();
    final remaining = books.length - displayBooks.length;
    final now = DateTime.now();

    return Container(
      width: 375,
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero Header
          Container(
            padding: const EdgeInsets.fromLTRB(28, 48, 28, 32),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bookmark, size: 16, color: Colors.black),
                        const SizedBox(width: 8),
                        Text(
                          'Olib Collection'.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '@$userName',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  (customTitle?.isEmpty ?? true)
                      ? '${_getMonth(now.month)} · Selection'
                      : customTitle!,
                  style: const TextStyle(
                    fontFamily: 'Serif',
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 3,
                  width: 40,
                  color: Colors.black,
                ),
                if (customContent != null && customContent!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    customContent!,
                    style: TextStyle(
                      fontFamily: 'Serif',
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // List
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              children: [
                ...displayBooks.map((book) => Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              _buildCover(book, width: 44, height: 66, radius: 2),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Serif',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        height: 1.2,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (book.author?.isNotEmpty == true) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        book.author!.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[600],
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey[300]),
                      ],
                    )),
                if (remaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      'Plus $remaining more books',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(28),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '"A book is a dream that you hold in your hand."',
                    style: const TextStyle(
                      fontFamily: 'Serif',
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // QR Code
                if (qrData != null)
                  _buildQrCode(size: 44, color: Colors.black),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Style 3: Glassmorphism (沉浸磨砂) ─────────────────────
  Widget _buildGlassStyle(BuildContext context) {
    // If we have books, use the first book's cover as bg
    final bgCover = books.isNotEmpty ? books.first.cover : null;
    final displayBooks = _getDisplayBooks();
    final remaining = books.length - displayBooks.length;

    return SizedBox(
      width: 375,
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: bgCover != null && bgCover.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: bgCover,
                    fit: BoxFit.cover,
                  )
                : Container(color: Colors.grey[800]),
          ),
          // Blur Filter
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: Colors.white.withValues(alpha:0.6), // 60% opacity white overlay
              ),
            ),
          ),
          // Content Card
          Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.85),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                       CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.black,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'O',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (customTitle?.isEmpty ?? true) ? 'My Collection' : customTitle!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              _getDateStr(),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (qrData != null)
                        _buildQrCode(size: 32, color: Colors.black87),
                    ],
                  ),
                  if (customContent != null && customContent!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      customContent!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // List
                  ...displayBooks.map((book) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            _buildCover(book, width: 40, height: 60, radius: 4),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                book.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),

                  if (remaining > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+ $remaining more books',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  // Simple Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Generated by Olib',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────

  Widget _buildQrCode({required double size, required Color color}) {
    if (qrData == null) return const SizedBox.shrink();
    return QrImageView(
      data: qrData!,
      version: QrVersions.auto,
      size: size,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
      dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: color),
      gapless: false,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────

  List<Book> _getDisplayBooks() {
    return books.length > maxDisplay ? books.sublist(0, maxDisplay) : books;
  }

  String _getDateStr() {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
  }

  String _getMonth(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return months[month - 1];
  }

  Widget _buildCover(Book book, {double width = 36, double height = 54, double radius = 0}) {
    // If radius > 0, clip it
    final child = SizedBox(
      width: width,
      height: height,
      child: book.cover != null && book.cover!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: book.cover!,
              fit: BoxFit.cover,
              memCacheWidth: (width * 3).toInt(), // for high res capture
              errorWidget: (_, __, ___) => _coverPlaceholder(),
              placeholder: (_, __) => _coverPlaceholder(),
            )
          : _coverPlaceholder(),
    );

    if (radius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      );
    }
    return child;
  }

  Widget _coverPlaceholder() {
    return Container(
      color: const Color(0xFFE0E0E0),
      child: const Center(
        child: Icon(Icons.book, size: 16, color: Colors.grey),
      ),
    );
  }
}
