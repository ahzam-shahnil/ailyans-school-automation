/// Model representation for a row in the library book catalog.
/// Maps to the `Books` table per §S27 (`frmBooks` at `0x00412598`, `ObjID: 3`).
class LibraryBookRow {
  final int bookId;
  final int? bookCatSubj;
  final String bookName;
  final String? bAuthor;
  final int? pages;
  final String?
  pulishedBy; // Typo preserved from legacy DB schema ('PulishedBy')
  final int? publishedYr;
  final int? bookPrice;
  final String? detail;
  final String? categoryName;

  const LibraryBookRow({
    required this.bookId,
    this.bookCatSubj,
    required this.bookName,
    this.bAuthor,
    this.pages,
    this.pulishedBy,
    this.publishedYr,
    this.bookPrice,
    this.detail,
    this.categoryName,
  });

  /// Factory constructor to parse SQLite row map.
  factory LibraryBookRow.fromMap(Map<String, dynamic> map) {
    return LibraryBookRow(
      bookId: map['BookID'] as int? ?? 0,
      bookCatSubj: map['BookCatSubj'] as int?,
      bookName: (map['BookName'] as String?)?.trim() ?? '',
      bAuthor: (map['BAuthor'] as String?)?.trim(),
      pages: map['Pages'] as int?,
      pulishedBy: (map['PulishedBy'] as String?)?.trim(),
      publishedYr: map['PublishedYr'] as int?,
      bookPrice: map['BookPrice'] as int?,
      detail: (map['Detail'] as String?)?.trim(),
      categoryName: (map['CategoryName'] as String?)?.trim(),
    );
  }

  /// Formatted accession number (e.g. '#1', '#4').
  String get accessionDisplay => '#$bookId';

  /// Display price formatted in Pakistani Rupees (e.g. 'Rs. 250').
  String get priceDisplay => 'Rs. ${bookPrice ?? 0}';
}
