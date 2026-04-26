import Foundation

struct FoodAPIResult: Identifiable {
    let id = UUID()
    let name: String
    let brand: String?
    let servingSize: Double
    let servingUnit: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    var fiber: Double = 0
}

actor FoodAPIService {
    static let shared = FoodAPIService()

    // MARK: - Codable Response Types

    private struct SearchResponse: Decodable {
        let products: [Product]?
    }

    private struct Product: Decodable {
        let productName: String?
        let brands: String?
        let servingSize: String?
        let servingQuantity: Double?
        let nutriments: Nutriments?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case brands
            case servingSize = "serving_size"
            case servingQuantity = "serving_quantity"
            case nutriments
        }
    }

    private struct Nutriments: Decodable {
        let energyKcal100g: Double?
        let proteins100g: Double?
        let carbohydrates100g: Double?
        let fat100g: Double?
        let fiber100g: Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case proteins100g = "proteins_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case fat100g = "fat_100g"
            case fiber100g = "fiber_100g"
        }
    }

    // MARK: - Search

    func searchFoods(query: String) async -> [FoodAPIResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }

        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&json=1&page_size=20")
        else {
            return []
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Cairn iOS App - Contact: dev@fittrack.app", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return []
            }

            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(SearchResponse.self, from: data)

            guard let products = searchResponse.products else {
                return []
            }

            return products.compactMap { product -> FoodAPIResult? in
                guard let name = product.productName, !name.isEmpty,
                      let nutriments = product.nutriments,
                      let kcal100g = nutriments.energyKcal100g,
                      let protein100g = nutriments.proteins100g,
                      let carbs100g = nutriments.carbohydrates100g,
                      let fat100g = nutriments.fat100g
                else {
                    return nil
                }

                let servingQty = product.servingQuantity ?? 100.0
                let servingUnit = parseServingUnit(from: product.servingSize)
                let factor = servingQty / 100.0
                let fiberVal = nutriments.fiber100g.map { round($0 * factor * 10) / 10 } ?? 0

                return FoodAPIResult(
                    name: name,
                    brand: product.brands,
                    servingSize: servingQty,
                    servingUnit: servingUnit,
                    calories: round(kcal100g * factor * 10) / 10,
                    protein: round(protein100g * factor * 10) / 10,
                    carbs: round(carbs100g * factor * 10) / 10,
                    fat: round(fat100g * factor * 10) / 10,
                    fiber: fiberVal
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Barcode Lookup

    private struct BarcodeResponse: Decodable {
        let status: Int
        let product: Product?
    }

    func fetchByBarcode(ean: String) async -> FoodAPIResult? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(ean).json") else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Cairn iOS App - Contact: dev@fittrack.app", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let decoded = try JSONDecoder().decode(BarcodeResponse.self, from: data)
            guard decoded.status == 1,
                  let product = decoded.product,
                  let name = product.productName, !name.isEmpty,
                  let nutriments = product.nutriments,
                  let kcal100g = nutriments.energyKcal100g,
                  let protein100g = nutriments.proteins100g,
                  let carbs100g = nutriments.carbohydrates100g,
                  let fat100g = nutriments.fat100g
            else {
                return nil
            }

            let servingQty = product.servingQuantity ?? 100.0
            let servingUnit = parseServingUnit(from: product.servingSize)
            let factor = servingQty / 100.0
            let fiberVal = nutriments.fiber100g.map { round($0 * factor * 10) / 10 } ?? 0

            return FoodAPIResult(
                name: name,
                brand: product.brands,
                servingSize: servingQty,
                servingUnit: servingUnit,
                calories: round(kcal100g * factor * 10) / 10,
                protein: round(protein100g * factor * 10) / 10,
                carbs: round(carbs100g * factor * 10) / 10,
                fat: round(fat100g * factor * 10) / 10,
                fiber: fiberVal
            )
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private func parseServingUnit(from servingSize: String?) -> String {
        guard let servingSize = servingSize?.lowercased() else {
            return "g"
        }
        if servingSize.contains("ml") {
            return "ml"
        } else if servingSize.contains("oz") {
            return "oz"
        } else if servingSize.contains("cup") {
            return "cup"
        } else if servingSize.contains("tbsp") {
            return "tbsp"
        } else if servingSize.contains("tsp") {
            return "tsp"
        } else if servingSize.contains("piece") || servingSize.contains("pc") {
            return "piece"
        } else if servingSize.contains("slice") {
            return "slice"
        }
        return "g"
    }
}
