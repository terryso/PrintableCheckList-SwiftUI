import SwiftUI

struct PreviewView: View {
    let projectID: UUID

    @EnvironmentObject private var store: ChecklistStore

    var body: some View {
        ScrollView {
            if let project = store.project(id: projectID) {
                VStack(alignment: .leading, spacing: 15) {
                    Text(project.title)
                        .font(.system(size: 32, weight: .bold))
                        .padding(.bottom, 4)

                    ForEach(project.items) { item in
                        HStack(alignment: .top, spacing: 20) {
                            Rectangle()
                                .stroke(.black, lineWidth: 2)
                                .frame(width: 20, height: 20)
                                .padding(.top, 5)

                            Text(item.title)
                                .font(.system(size: 16))
                                .lineSpacing(7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.leading, 35)
                        .padding(.bottom, 15)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(.white)
        .foregroundStyle(.black)
        .navigationTitle(Text("Preview"))
    }
}
