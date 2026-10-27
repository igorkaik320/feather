//
//  ASRepository+Scarlet.swift
//  AltSourceKit
//

import Foundation

// Scarlet repositories use `{"META": {...}, "<Category>": [ {...} ]}`.

struct ASScarletRepository: Decodable {
	var name: String?
	var iconURL: URL?
	var apps: [ASRepository.App]

	private struct Meta: Decodable {
		var repoName: String?
		var repoIcon: String?
	}

	private struct Item: Decodable {
		var name: String?
		var version: String?
		var down: String?
		var bundleID: String?
		var description: String?
		var icon: String?
		var dev: String?
		var category: String?
		var changelog: String?
		var screenshots: [String]?
	}

	private struct LossyItem: Decodable {
		var item: Item?

		init(from decoder: any Decoder) throws {
			self.item = try? Item(from: decoder)
		}
	}

	private struct DynamicKey: CodingKey {
		var stringValue: String
		var intValue: Int? { nil }

		init?(stringValue: String) { self.stringValue = stringValue }
		init?(intValue: Int) { nil }
	}

	private static let metaKey = DynamicKey(stringValue: "META")!

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: DynamicKey.self)
		let meta = try container.decode(Meta.self, forKey: Self.metaKey)

		self.name = meta.repoName
		self.iconURL = meta.repoIcon.flatMap(URL.init(string:))

		let categoryKeys = container.allKeys
			.filter { $0.stringValue != Self.metaKey.stringValue }
			.sorted { $0.stringValue < $1.stringValue }

		var apps: [ASRepository.App] = []
		for key in categoryKeys {
			guard let items = try? container.decode([LossyItem].self, forKey: key) else {
				continue
			}

			for item in items.compactMap(\.item) {
				guard
					let down = item.down,
					let downloadURL = URL(string: down)
				else {
					continue
				}

				apps.append(ASRepository.App(
					id: item.bundleID,
					name: item.name,
					developer: item.dev,
					version: item.version,
					versionDescription: item.changelog,
					downloadURL: downloadURL,
					localizedDescription: item.description,
					iconURL: item.icon.flatMap(URL.init(string:)),
					category: item.category ?? key.stringValue,
					screenshotURLs: item.screenshots?.compactMap(URL.init(string:))
				))
			}
		}

		self.apps = apps
	}
}

extension ASRepository.App {
	init(
		id: String?,
		name: String?,
		developer: String?,
		version: String?,
		versionDescription: String?,
		downloadURL: URL?,
		localizedDescription: String?,
		iconURL: URL?,
		category: String?,
		screenshotURLs: [URL]?
	) {
		self.id = id
		self.name = name
		self.developer = developer
		self.version = version
		self.versionDescription = versionDescription
		self.downloadURL = downloadURL
		self.localizedDescription = localizedDescription
		self.iconURL = iconURL
		self.category = category
		self.beta = false
		self.screenshotURLs = screenshotURLs
	}
}
