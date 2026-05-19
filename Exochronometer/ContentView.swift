import SwiftUI
import SwiftData
import ExochronometerCore

struct ContentView: View {
    @State private var currentPage: AppPage = .circles

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                AppHeader(currentPage: $currentPage)

                Group {
                    switch currentPage {
                    case .circles:
                        CirclesPage()
                    case .timeline:
                        TimelinePage()
                    case .geometryHarmonics:
                        GeometryHarmonicsPage()
                    case .harmonicAnalysis:
                        HarmonicAnalysisPage()
                    case .spatialAnalysis:
                        SpatialAnalysisPage()
                    case .misc:
                        MiscPage()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
