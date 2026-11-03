import Foundation
import MapKit

/// Keeps the map readable at every zoom level. The visible area is split into a grid (finer when
/// zoomed in), and only the most important item in each cell is drawn. The kept item remembers how
/// many others it stands for, so the map can show "+3" and zoom in when tapped.
enum MapDeclutter {
    private struct Cell: Hashable {
        let x: Int
        let y: Int
    }

    struct Pin<Item> {
        let item: Item
        /// Items in the same cell that aren't drawn
        let hiddenCount: Int
    }

    /// - Parameters:
    ///   - columns: grid columns across the visible width; rows follow from the region's shape
    ///   - rank: lower is more important (drawn first)
    static func thin<Item>(
        _ items: [Item],
        in region: MKCoordinateRegion,
        columns: Int,
        coordinate: (Item) -> CLLocationCoordinate2D,
        rank: (Item) -> Double
    ) -> [Pin<Item>] {
        let cellWidth = region.span.longitudeDelta / Double(max(columns, 1))
        // Roughly square cells on screen: a degree of longitude is shorter than one of latitude up north
        let cellHeight = cellWidth * cos(region.center.latitude * .pi / 180)
        guard cellWidth > 0, cellHeight > 0 else { return items.map { Pin(item: $0, hiddenCount: 0) } }

        // A margin around the screen so pins don't pop in while panning
        let marginLatitude = region.span.latitudeDelta * 0.75
        let marginLongitude = region.span.longitudeDelta * 0.75
        let minLatitude = region.center.latitude - marginLatitude
        let maxLatitude = region.center.latitude + marginLatitude
        let minLongitude = region.center.longitude - marginLongitude
        let maxLongitude = region.center.longitude + marginLongitude

        var best: [Cell: (item: Item, rank: Double, count: Int)] = [:]
        for item in items {
            let point = coordinate(item)
            guard (minLatitude...maxLatitude).contains(point.latitude),
                  (minLongitude...maxLongitude).contains(point.longitude) else { continue }
            let cell = Cell(
                x: Int(((point.longitude - minLongitude) / cellWidth).rounded(.down)),
                y: Int(((point.latitude - minLatitude) / cellHeight).rounded(.down))
            )
            let itemRank = rank(item)
            if let current = best[cell] {
                best[cell] = itemRank < current.rank
                    ? (item, itemRank, current.count + 1)
                    : (current.item, current.rank, current.count + 1)
            } else {
                best[cell] = (item, itemRank, 1)
            }
        }
        return best.values
            .sorted { $0.rank < $1.rank }
            .map { Pin(item: $0.item, hiddenCount: $0.count - 1) }
    }
}
