//
//  BatchOperationBar.swift
//  Legado-iOS
//
//  书架批量操作工具栏
//

import SwiftUI

struct BatchOperationBar: View {
    let selectedCount: Int
    let totalCount: Int
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onMoveToGroup: () -> Void
    let onDelete: () -> Void
    let onCacheAll: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("取消") { onCancel() }
                Spacer()
                Text("已选 \(selectedCount) 本").font(.headline)
                Spacer()
                Button(selectedCount == totalCount ? "取消全选" : "全选") {
                    selectedCount == totalCount ? onDeselectAll() : onSelectAll()
                }
            }
            
            HStack(spacing: 20) {
                Button(action: onMoveToGroup) {
                    VStack {
                        Image(systemName: "folder.badge.plus")
                        Text("移动").font(.caption2)
                    }
                }
                .disabled(selectedCount == 0)
                
                Button(action: onCacheAll) {
                    VStack {
                        Image(systemName: "arrow.down.circle")
                        Text("缓存").font(.caption2)
                    }
                }
                .disabled(selectedCount == 0)
                
                Button(action: onDelete) {
                    VStack {
                        Image(systemName: "trash").foregroundColor(.red)
                        Text("删除").font(.caption2).foregroundColor(.red)
                    }
                }
                .disabled(selectedCount == 0)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 5)
    }
}