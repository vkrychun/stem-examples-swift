import UIKit
import SwiftUI
import StemRuntimeSDK
import StemJSON
import StemDependencies

final class RootViewController: UICollectionViewController {

    private let modules = JSONCatalog.Module.allCases

    private let standaloneRenderer = StemRuntime()
        .register(FirebaseRepository.self, as: AppRepositoryType.firebase)
        .register(LocationService.self, as: AppServiceType.location)

    private let embeddedRenderer = StemRuntime()
        .navigationEmbedded()

    private var apps: [(module: JSONCatalog.Module, render: StemRender?)] = []
    private var closeTask: Task<Void, Never>?

    init() {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .estimated(150)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(150)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])
        group.interItemSpacing = .fixed(16)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)

        let layout = UICollectionViewCompositionalLayout(section: section)
        super.init(collectionViewLayout: layout)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Stem Examples"
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.register(ModuleTileCell.self, forCellWithReuseIdentifier: ModuleTileCell.reuseID)
        Task { await validateAll() }
    }

    @MainActor
    private func validateAll() async {
        for module in modules {
            let renderer = module.isEmbedded ? embeddedRenderer : standaloneRenderer
            guard let data = try? JSONCatalog.data(for: module),
                  let render = try? await renderer.validate(data: data).get()
            else { continue }
            apps.append((module: module, render: render))
        }
        collectionView.reloadData()
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        apps.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ModuleTileCell.reuseID, for: indexPath) as! ModuleTileCell
        cell.configure(with: apps[indexPath.item].module)
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let entry = apps[indexPath.item]

        if entry.render == nil {
            Task {
                let renderer = entry.module.isEmbedded ? embeddedRenderer : standaloneRenderer
                guard let data = try? JSONCatalog.data(for: entry.module),
                      let render = try? await renderer.validate(data: data).get()
                else { return }
                apps[indexPath.item].render = render
                present(module: entry.module, render: render)
            }
        } else if let render = entry.render {
            present(module: entry.module, render: render)
        }
    }

    private func present(module: JSONCatalog.Module, render: StemRender) {
        let vc = makeHostingVC(render)

        if module.isEmbedded {
            navigationController?.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true)
            observeClose(render: render)
        }
    }

    private func makeHostingVC(_ render: StemRender) -> UIViewController {
        UIHostingController(rootView: render)
    }

    private func observeClose(render: StemRender) {
        closeTask?.cancel()
        closeTask = Task { [weak self] in
            guard let self else { return }
            for await value in standaloneRenderer.stream(for: "onClose", from: render) {
                guard let closed = value as? Bool, closed else { continue }
                await standaloneRenderer.kill(render)
                markKilled(render.id)
                await MainActor.run {
                    self.dismiss(animated: true)
                }
                break
            }
        }
    }

    private func markKilled(_ id: String) {
        if let idx = apps.firstIndex(where: { $0.render?.id == id }) {
            apps[idx].render = nil
        }
    }
}

private extension JSONCatalog.Module {
    /// Modules whose navigation participates in the host's UINavigationController.
    var isEmbedded: Bool { false }
}

private final class ModuleTileCell: UICollectionViewCell {

    static let reuseID = "ModuleTileCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous

        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 32)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.heightAnchor.constraint(equalToConstant: 40),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with module: JSONCatalog.Module) {
        iconView.image = UIImage(systemName: module.iconName)
        iconView.tintColor = uiColor(for: module.iconColor)
        titleLabel.text = module.displayName
        subtitleLabel.text = module.subtitle
    }

    private func uiColor(for name: String) -> UIColor {
        switch name {
        case "orange": .systemOrange; case "purple": .systemPurple; case "blue": .systemBlue
        case "green": .systemGreen; case "teal": .systemTeal; case "indigo": .systemIndigo
        case "pink": .systemPink; case "brown": .systemBrown; case "red": .systemRed
        case "mint": .systemMint; default: .tintColor
        }
    }
}

