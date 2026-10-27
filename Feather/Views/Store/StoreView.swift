//
//  StoreView.swift
//  Feather
//

import CoreData
import SwiftUI
import AltSourceKit
import NimbleViews
import NukeUI

// MARK: - View
struct StoreView: View {
	@StateObject var viewModel = SourcesViewModel.shared
	@State private var _searchText = ""

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	struct Entry: Identifiable {
		let id: String
		let sourceURL: URL?
		let source: ASRepository
		let app: ASRepository.App

		var category: String {
			let trimmed = app.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			return trimmed.isEmpty ? .localized("Other") : trimmed.capitalized
		}
	}

	private var _entries: [Entry] {
		_sources.flatMap { source -> [Entry] in
			guard let repository = viewModel.sources[source] else { return [] }
			let prefix = source.sourceURL?.absoluteString ?? (source.identifier ?? "")
			return repository.apps.map { app in
				Entry(
					id: "\(prefix)|\(app.currentUniqueId)",
					sourceURL: source.sourceURL,
					source: repository,
					app: app
				)
			}
		}
	}

	private var _filteredEntries: [Entry] {
		guard !_searchText.isEmpty else { return _entries }
		return _entries.filter {
			$0.app.currentName.localizedCaseInsensitiveContains(_searchText)
				|| ($0.app.id?.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}

	struct Category: Identifiable {
		let name: String
		let entries: [Entry]
		var id: String { name }
	}

	private var _categories: [Category] {
		Dictionary(grouping: _filteredEntries, by: { $0.category })
			.map { Category(name: $0.key, entries: $0.value) }
			.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
	}

	private var _featured: [Entry] {
		let explicit = _entries.filter { entry in
			guard let id = entry.app.id else { return false }
			return entry.source.featuredApps?.contains(id) ?? false
		}
		if !explicit.isEmpty { return Array(explicit.prefix(10)) }
		return Array(_categories.compactMap { $0.entries.first }.prefix(10))
	}

	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Store")) {
			List {
				if _searchText.isEmpty, !_featured.isEmpty {
					Section {
						ScrollView(.horizontal, showsIndicators: false) {
							HStack(spacing: 14) {
								ForEach(_featured) { entry in
									NavigationLink {
										_detail(for: entry)
									} label: {
										StoreFeaturedCardView(entry: entry)
									}
									.buttonStyle(.plain)
								}
							}
							.padding(.vertical, 6)
						}
						.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
					} header: {
						Text(String.localized("Featured"))
					}
				}

				ForEach(_categories) { category in
					Section {
						ForEach(category.entries) { entry in
							NavigationLink {
								_detail(for: entry)
							} label: {
								SourceAppsCellView(
									sourceURL: entry.sourceURL,
									source: entry.source,
									app: entry.app
								)
							}
						}
					} header: {
						Text("\(category.name) (\(category.entries.count))")
					}
				}
			}
			.listStyle(.insetGrouped)
			.searchable(text: $_searchText, placement: .platform())
			.overlay {
				if _entries.isEmpty {
					if viewModel.isFinished || _sources.isEmpty {
						_emptyView()
					} else {
						ProgressView()
					}
				}
			}
			.refreshable {
				await viewModel.fetchSources(_sources, refresh: true)
			}
		}
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
		}
	}

	@ViewBuilder
	private func _detail(for entry: Entry) -> some View {
		SourceAppsDetailView(
			sourceURL: entry.sourceURL,
			source: entry.source,
			app: entry.app
		)
	}

	@ViewBuilder
	private func _emptyView() -> some View {
		VStack(spacing: 8) {
			Image(systemName: "bag")
				.font(.largeTitle)
				.foregroundStyle(.secondary)
			Text(.localized("No Apps"))
				.font(.headline)
			Text(.localized("Add a repository in the Sources tab to fill the store."))
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.padding()
	}
}

// MARK: - Featured card
struct StoreFeaturedCardView: View {
	let entry: StoreView.Entry

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if let iconURL = entry.app.iconURL {
				LazyImage(url: iconURL) { state in
					if let image = state.image {
						image.appIconStyle(size: 72)
					} else {
						_placeholder
					}
				}
			} else {
				_placeholder
			}

			Text(entry.app.currentName)
				.font(.subheadline.bold())
				.lineLimit(1)
			Text(entry.category)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
		}
		.frame(width: 96, alignment: .leading)
	}

	private var _placeholder: some View {
		Image(systemName: "app.dashed")
			.font(.system(size: 40))
			.foregroundStyle(.secondary)
			.frame(width: 72, height: 72)
	}
}
