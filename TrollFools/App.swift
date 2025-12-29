//
//  App.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Combine
import Foundation

final class App: ObservableObject {
    let bid: String
    let name: String
    let latinName: String
    let type: String
    let teamID: String
    let url: URL
    let version: String?
    let isAdvertisement: Bool

    @Published var isDetached: Bool = false
    @Published var isAllowedToAttachOrDetach: Bool = false
    @Published var isInjected: Bool = false
    @Published var hasPersistedAssets: Bool = false

    lazy var icon: UIImage? = UIImage._applicationIconImage(
        forBundleIdentifier: bid, format: 0, scale: 3.0)
    var alternateIcon: UIImage?

    lazy var isUser: Bool = type == "User"
    lazy var isSystem: Bool = !isUser
    lazy var isFromApple: Bool = bid.hasPrefix("com.apple.")
    lazy var isFromTroll: Bool = isSystem && !isFromApple
    lazy var isRemovable: Bool = url.path.contains("/var/containers/Bundle/Application/")

    weak var appList: AppListModel?
    private var cancellables: Set<AnyCancellable> = []
    private static let reloadSubject = PassthroughSubject<String, Never>()
    private var statusLoaded = false

    init(
        bid: String,
        name: String,
        type: String,
        teamID: String,
        url: URL,
        version: String? = nil,
        alternateIcon: UIImage? = nil,
        isAdvertisement: Bool = false
    ) {
        self.bid = bid
        self.name = name
        self.type = type
        self.teamID = teamID
        self.url = url
        self.version = version
        self.alternateIcon = alternateIcon
        self.isAdvertisement = isAdvertisement
        self.latinName =
            name.applyingTransform(.toLatin, reverse: false)?.applyingTransform(
                .stripDiacritics, reverse: false)?.components(separatedBy: .whitespaces).joined()
            ?? ""
        Self.reloadSubject
            .filter { $0 == bid }
            .sink { [weak self] _ in
                self?._reload()
            }
            .store(in: &cancellables)

        // Load status asynchronously to avoid blocking initialization
        loadStatusAsync()
    }

    private func loadStatusAsync() {
        guard !statusLoaded else { return }
        statusLoaded = true

        // Load status on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let isDetached = InjectorV3.main.isMetadataDetachedInBundle(self.url)
            let isAllowedToAttachOrDetach =
                self.type == "User"
                && InjectorV3.main.isAllowedToAttachOrDetachMetadataInBundle(self.url)
            let isInjected = InjectorV3.main.checkIsInjectedAppBundle(self.url)
            let hasPersistedAssets = InjectorV3.main.hasPersistedAssets(bid: self.bid)

            DispatchQueue.main.async {
                self.isDetached = isDetached
                self.isAllowedToAttachOrDetach = isAllowedToAttachOrDetach
                self.isInjected = isInjected
                self.hasPersistedAssets = hasPersistedAssets
            }
        }
    }

    func reload() {
        Self.reloadSubject.send(bid)
    }

    private func _reload() {
        reloadDetachedStatus()
        reloadInjectedStatus()
    }

    private func reloadDetachedStatus() {
        statusLoaded = false
        loadStatusAsync()
    }

    private func reloadInjectedStatus() {
        statusLoaded = false
        loadStatusAsync()
    }
}
