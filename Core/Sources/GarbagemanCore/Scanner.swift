import Foundation

struct Scanner {
    private let categoriesByID: [CategoryID: any CleanupCategory]

    init() {
        self.init(categories: CategoryFactory.allCategories())
    }

    init(categories: [any CleanupCategory]) {
        var mapped: [CategoryID: any CleanupCategory] = [:]
        for category in categories {
            mapped[category.id] = category
        }
        self.categoriesByID = mapped
    }

    func scan(
        selectedCategoryIDs: [CategoryID],
        context: ScanContext,
        onCategoryScanned: ((ScanProgress) -> Void)? = nil
    ) -> [CategoryPlan] {
        let totalCount = selectedCategoryIDs.count
        var completedCount = 0

        return selectedCategoryIDs.compactMap { categoryID in
            guard let category = categoriesByID[categoryID] else {
                return nil
            }

            let plan = category.scan(using: context)
            completedCount += 1
            onCategoryScanned?(
                ScanProgress(
                    categoryID: categoryID,
                    completedCategoryCount: completedCount,
                    totalCategoryCount: totalCount,
                    plan: plan
                )
            )
            return plan
        }
    }
}
