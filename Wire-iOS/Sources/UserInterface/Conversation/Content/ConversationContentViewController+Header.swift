//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import UIKit
import Cartography

extension ConversationContentViewController {
    @objc func createConstraints() {
        constrain(self.view, tableView) { (selfView, tableView) in
            selfView.edges == tableView.edges
        }

        createHeaderConstraints()
    }

    func createHeaderConstraints() {
        guard let connectionViewController = connectionViewController else { return }

        constrain(connectionViewController.view, tableView) { (headerView, tableView) in
            headerView.centerX == tableView.centerX
            headerView.width == tableView.width
            headerViewHeight = headerView.height == 0
//            headerView.top == tableView.top ///footer is header
//            headerView.bottom == tableView.bottom ///footer is header
        }

        headerViewHeight?.constant = headerHeight()
    }

    @objc func createTableView() {
        tableView = UpsideDownTableView(frame: CGRect.zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
    }

    /// TODO: update
    @objc func createTableViewHeader() {
        // Don't display the conversation header if the message window doesn't include the first message.
        guard messageWindow.messages.count == conversation.messages.count else { return }


        let connectionOrOneOnOne = conversation.conversationType == .connection || conversation.conversationType == .oneOnOne

        guard connectionOrOneOnOne, let otherParticipant = conversation.firstActiveParticipantOtherThanSelf() else { return }

        if let session = ZMUserSession.shared() {
            connectionViewController = UserConnectionViewController(userSession: session, user: otherParticipant)
        }

        if let headerView = connectionViewController?.view {
            headerView.layoutMargins = UIEdgeInsetsMake(0, 20, 0, 20)
            headerView.translatesAutoresizingMaskIntoConstraints = false

            tableView.tableHeaderView = headerView
        }
    }

    func updateHeaderViewSize() {
        let fittingSize = CGSize(width: tableView.bounds.size.width, height: headerHeight())

            headerViewHeight?.constant = fittingSize.height
    }

    /// Update header view's frame.
    func updateHeaderViewFrame() {
        guard let headerView = tableView.tableHeaderView else { return }

        // Update the size of the header based on its internal content.
        headerView.layoutIfNeeded()

        // ***Trigger table view to know that header should be updated.
//        let header = tableView.tableHeaderView
//        tableView.tableHeaderView = header
    }

}
