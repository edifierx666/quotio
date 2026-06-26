//
//  SidebarView.swift
//  Edx
//
//  Note: This file is no longer used - sidebar is now integrated in EdxApp.swift
//  using NavigationSplitView which automatically gets Liquid Glass styling.
//

import SwiftUI

// Legacy SidebarView - kept for reference
struct SidebarView: View {
    @Environment(QuotaViewModel.self) private var viewModel
    @Binding var isExpanded: Bool
    @Binding var isPinned: Bool
    
    var body: some View {
        // Now using NavigationSplitView in EdxApp.swift
        EmptyView()
    }
}
