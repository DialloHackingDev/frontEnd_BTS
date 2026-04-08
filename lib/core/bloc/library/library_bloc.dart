import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../models/library_item.dart';
import '../../network/api_service.dart';

/// Events pour LibraryBloc
abstract class LibraryEvent extends Equatable {
  const LibraryEvent();

  @override
  List<Object?> get props => [];
}

class LoadLibrary extends LibraryEvent {
  final bool reset;
  final int page;
  final int limit;

  const LoadLibrary({this.reset = false, this.page = 1, this.limit = 10});

  @override
  List<Object?> get props => [reset, page, limit];
}

class RefreshLibrary extends LibraryEvent {
  const RefreshLibrary();
}

class FilterLibrary extends LibraryEvent {
  final String filter;

  const FilterLibrary(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// States pour LibraryBloc
abstract class LibraryState extends Equatable {
  const LibraryState();

  @override
  List<Object?> get props => [];
}

class LibraryInitial extends LibraryState {}

class LibraryLoading extends LibraryState {
  final List<LibraryItem> currentItems;
  final bool isFirstFetch;

  const LibraryLoading({this.currentItems = const [], this.isFirstFetch = false});

  @override
  List<Object?> get props => [currentItems, isFirstFetch];
}

class LibraryLoaded extends LibraryState {
  final List<LibraryItem> items;
  final int currentPage;
  final int totalPages;
  final bool hasMore;
  final String? filter;

  const LibraryLoaded({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    this.hasMore = true,
    this.filter,
  });

  LibraryLoaded copyWith({
    List<LibraryItem>? items,
    int? currentPage,
    int? totalPages,
    bool? hasMore,
    String? filter,
  }) {
    return LibraryLoaded(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      hasMore: hasMore ?? this.hasMore,
      filter: filter ?? this.filter,
    );
  }

  @override
  List<Object?> get props => [items, currentPage, totalPages, hasMore, filter];
}

class LibraryError extends LibraryState {
  final String message;
  final List<LibraryItem>? cachedItems;

  const LibraryError(this.message, {this.cachedItems});

  @override
  List<Object?> get props => [message, cachedItems];
}

/// BLoC pour la gestion de la bibliothèque
/// Implémente la pagination, le filtrage et le refresh
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final ApiService _apiService;

  LibraryBloc({ApiService? apiService}) 
      : _apiService = apiService ?? ApiService(),
        super(LibraryInitial()) {
    on<LoadLibrary>(_onLoadLibrary);
    on<RefreshLibrary>(_onRefreshLibrary);
    on<FilterLibrary>(_onFilterLibrary);
  }

  Future<void> _onLoadLibrary(
    LoadLibrary event,
    Emitter<LibraryState> emit,
  ) async {
    final currentState = state;
    List<LibraryItem> currentItems = [];
    int page = event.page;

    if (currentState is LibraryLoaded) {
      currentItems = event.reset ? [] : currentState.items;
      page = event.reset ? 1 : currentState.currentPage + 1;
    }

    // Ne pas charger si on est au dernier page (sauf reset)
    if (currentState is LibraryLoaded && 
        !event.reset && 
        !currentState.hasMore) {
      return;
    }

    emit(LibraryLoading(
      currentItems: currentItems,
      isFirstFetch: currentItems.isEmpty,
    ));

    try {
      final response = await _apiService.get(
        '/library',
        queryParams: {'page': '$page', 'limit': '${event.limit}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> raw = data['data'] ?? data;
        final newItems = raw.map((json) => LibraryItem.fromJson(json)).toList();
        final totalPages = data['totalPages'] ?? 1;

        final allItems = event.reset ? newItems : [...currentItems, ...newItems];
        
        emit(LibraryLoaded(
          items: allItems,
          currentPage: page,
          totalPages: totalPages,
          hasMore: page < totalPages,
        ));
      } else {
        emit(LibraryError(
          'Erreur serveur: ${response.statusCode}',
          cachedItems: currentItems.isNotEmpty ? currentItems : null,
        ));
      }
    } catch (e) {
      emit(LibraryError(
        'Erreur de connexion: $e',
        cachedItems: currentItems.isNotEmpty ? currentItems : null,
      ));
    }
  }

  Future<void> _onRefreshLibrary(
    RefreshLibrary event,
    Emitter<LibraryState> emit,
  ) async {
    add(const LoadLibrary(reset: true));
  }

  Future<void> _onFilterLibrary(
    FilterLibrary event,
    Emitter<LibraryState> emit,
  ) async {
    final currentState = state;
    if (currentState is LibraryLoaded) {
      // Filtrage côté client pour l'instant
      // Pour un vrai filtrage serveur, il faudrait ajouter un paramètre à l'API
      emit(currentState.copyWith(filter: event.filter));
    }
  }
}
