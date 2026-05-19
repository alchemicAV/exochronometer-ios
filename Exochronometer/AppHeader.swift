import SwiftUI

struct AppHeader: View {
    @Binding var currentPage: AppPage

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
                .overlay(alignment: .trailing) {
                    Color.clear.frame(width: 36, height: 36)
                }

            VStack(spacing: 4) {
                Text("EXOCHRONOMETER")
                    .font(.system(size: 14, weight: .light, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(.white.opacity(0.7))
                Text(currentPage == .circles ? "JOURNAL" : currentPage.label.uppercased())
                    .font(.system(size: 9, weight: .light, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.35))
            }

            Spacer()
                .overlay(alignment: .leading) {
                    Menu {
                        ForEach(AppPage.allCases) { page in
                            Button {
                                currentPage = page
                            } label: {
                                if page == currentPage {
                                    Label(page.label, systemImage: "checkmark")
                                } else {
                                    Text(page.label)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .offset(x: 25, y: -10)
                }
        }
        .padding(.top, 16)
    }
}
