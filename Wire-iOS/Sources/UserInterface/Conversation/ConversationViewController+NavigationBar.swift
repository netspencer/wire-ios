//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
import WireSyncEngine
import Cartography

public extension ZMConversationList {
    func hasUnreadMessages(excluding: ZMConversation) -> Bool {
        return self.conversations().filter { $0 != excluding }.map { $0.estimatedUnreadCount }.reduce(0, +) > 0
    }

    func conversations() -> [ZMConversation] {
        return self.flatMap { $0 as? ZMConversation }
    }
}

// MARK: - Update left navigator bar item when size class changes
extension ConversationViewController {

    override open func willTransition(to newCollection: UITraitCollection,
                                      with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        self.updateLeftNavigationBarItems()
    }

}

public extension ConversationViewController {
    func addCallStateObserver() -> Any? {
        return conversation.voiceChannel?.addCallStateObserver(self)
    }
    
    var audioCallButton: UIBarButtonItem {
        let button = UIBarButtonItem(icon: .callAudio, target: self, action: #selector(ConversationViewController.voiceCallItemTapped(_:)))
        button.accessibilityIdentifier = "audioCallBarButton"
        button.accessibilityTraits |= UIAccessibilityTraitStartsMediaSession
        button.accessibilityLabel = "call.actions.label.make_audio_call".localized
        return button
    }

    var videoCallButton: UIBarButtonItem {
        let button = UIBarButtonItem(icon: .callVideo, target: self, action: #selector(ConversationViewController.videoCallItemTapped(_:)))
        button.accessibilityIdentifier = "videoCallBarButton"
        button.accessibilityTraits |= UIAccessibilityTraitStartsMediaSession
        button.accessibilityLabel = "call.actions.label.make_video_call".localized
        return button
    }

    var joinCallButton: UIBarButtonItem {
        let button = IconButton()
        button.adjustsTitleWhenHighlighted = true
        button.adjustBackgroundImageWhenHighlighted = true
        button.setTitle("conversation_list.right_accessory.join_button.title".localized.uppercased(), for: .normal)
        button.accessibilityLabel = "conversation.join_call.voiceover".localized
        button.accessibilityTraits |= UIAccessibilityTraitStartsMediaSession
        button.titleLabel?.font = FontSpec(.small, .semibold).font
        button.backgroundColor = UIColor(for: .strongLimeGreen)
        button.addTarget(self, action: #selector(joinCallButtonTapped), for: .touchUpInside)
        button.contentEdgeInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        button.bounds.size = button.systemLayoutSizeFitting(CGSize(width: .max, height: 24))
        button.layer.cornerRadius = button.bounds.height / 2
        return UIBarButtonItem(customView: button)
    }

    var backButton: UIBarButtonItem {
        let hasUnreadInOtherConversations = self.hasUnreadMessagesInOtherConversations
        let arrowIcon: ZetaIconType = hasUnreadInOtherConversations ? .backArrowWithDot : .backArrow
        let icon: ZetaIconType = (self.parent?.wr_splitViewController?.layoutSize == .compact) ? arrowIcon : .hamburger
        let action = #selector(ConversationViewController.onBackButtonPressed(_:))
        let button = UIBarButtonItem(icon: icon, target: self, action: action)
        button.accessibilityIdentifier = "ConversationBackButton"
        button.accessibilityLabel = "general.back".localized

        if hasUnreadInOtherConversations {
            button.tintColor = UIColor.accent()
            button.accessibilityValue = "conversation_list.voiceover.unread_messages.hint".localized
        }
        
        return button
    }

    var collectionsBarButtonItem: UIBarButtonItem {
        let showingSearchResults = (self.collectionController?.isShowingSearchResults ?? false)
        let action = #selector(ConversationViewController.onCollectionButtonPressed(_:))
        let button = UIBarButtonItem(icon: showingSearchResults ? .searchOngoing : .search, target: self, action: action)
        button.accessibilityIdentifier = "collection"
        button.accessibilityLabel = "conversation.action.search".localized
        
        if showingSearchResults {
            button.tintColor = UIColor.accent()
        }
        
        return button
    }

    var hasUnreadMessagesInOtherConversations: Bool {
        guard let userSession = ZMUserSession.shared() else {
            return false
        }
        return ZMConversationList.conversations(inUserSession: userSession).hasUnreadMessages(excluding: self.conversation)
    }

    public func rightNavigationItems(forConversation conversation: ZMConversation) -> [UIBarButtonItem] {
        guard !conversation.isReadOnly, conversation.lastServerSyncedActiveParticipants.count != 0 else { return [] }

        if conversation.canJoinCall {
            return [joinCallButton]
        } else if conversation.isCallOngoing {
            return []
        } else if conversation.canStartVideoCall {
            return [audioCallButton, videoCallButton]
        } else {
            return [audioCallButton]
        }
    }

    public func leftNavigationItems(forConversation conversation: ZMConversation) -> [UIBarButtonItem] {
        var items: [UIBarButtonItem] = []

        if self.parent?.wr_splitViewController?.layoutSize != .regularLandscape {
            items.append(backButton)
        }

        if self.shouldShowCollectionsButton() {
            items.append(collectionsBarButtonItem)
        }

        return items
    }

    public func updateRightNavigationItemsButtons() {
        if UIApplication.isLeftToRightLayout {
            navigationItem.rightBarButtonItems = rightNavigationItems(forConversation: conversation)
        } else {
            navigationItem.rightBarButtonItems = leftNavigationItems(forConversation: conversation)
        }
    }

    /// Update left navigation bar items
    func updateLeftNavigationBarItems() {
        if UIApplication.isLeftToRightLayout {
            navigationItem.leftBarButtonItems = leftNavigationItems(forConversation: conversation)
        } else {
            navigationItem.leftBarButtonItems = rightNavigationItems(forConversation: conversation)
        }
    }

    private func shouldShowCollectionsButton() -> Bool {
        switch self.conversation.conversationType {
        case .group: return true
        case .oneOnOne:
            if let connection = conversation.connection,
                connection.status != .pending && connection.status != .sent {
                return true
            } else {
                return nil != conversation.teamRemoteIdentifier
            }
        default: return false
        }
    }

    func voiceCallItemTapped(_ sender: UIBarButtonItem) {
        startCallController.startAudioCall(started: ConversationInputBarViewController.endEditingMessage)
    }

    func videoCallItemTapped(_ sender: UIBarButtonItem) {
        startCallController.startVideoCall(started: ConversationInputBarViewController.endEditingMessage)
    }

    private dynamic func joinCallButtonTapped(_sender: AnyObject!) {
        startCallController.joinCall()
    }

    func onCollectionButtonPressed(_ sender: AnyObject!) {
        if self.collectionController == .none {
            let collections = CollectionsViewController(conversation: conversation)
            collections.delegate = self

            collections.onDismiss = { [weak self] _ in

                guard let `self` = self, let collectionController = self.collectionController else {
                    return
                }

                collectionController.dismiss(animated: true, completion: {
                    UIApplication.shared.wr_updateStatusBarForCurrentControllerAnimated(true)
                })
            }
            self.collectionController = collections
        } else {
            self.collectionController?.refetchCollection()
        }

        collectionController?.shouldTrackOnNextOpen = true

        let navigationController = KeyboardAvoidingViewController(viewController: self.collectionController!).wrapInNavigationController(RotationAwareNavigationController.self)

        ZClientViewController.shared()?.present(navigationController, animated: true, completion: {
            UIApplication.shared.wr_updateStatusBarForCurrentControllerAnimated(true)
        })
    }

    internal func dismissCollectionIfNecessary() {
        if let collectionController = self.collectionController {
            collectionController.dismiss(animated: false)
        }
    }
}

extension ConversationViewController: CollectionsViewControllerDelegate {
    public func collectionsViewController(_ viewController: CollectionsViewController, performAction action: MessageAction, onMessage message: ZMConversationMessage) {
        switch action {
        case .forward:
            viewController.dismiss(animated: true) {
                self.contentViewController.scroll(to: message) { [weak self] cell in
                    guard let `self` = self else {
                        return
                    }
                    self.contentViewController.showForwardFor(message: message, fromCell: cell)
                }
            }

        case .showInConversation:
            viewController.dismiss(animated: true) { [weak self] in
                guard let `self` = self else {
                    return
                }
                self.contentViewController.scroll(to: message) { cell in
                    cell.flashBackground()
                }
            }
        default:
            self.contentViewController.wants(toPerform: action, for: message)
            break
        }
    }
}

extension ConversationViewController: WireCallCenterCallStateObserver {

    public func callCenterDidChange(callState: CallState, conversation: ZMConversation, caller: ZMUser, timestamp: Date?) {
        updateRightNavigationItemsButtons()
    }

}

extension ZMConversation {

    /// Whether there is an incoming or inactive incoming call that can be joined.
    var canJoinCall: Bool {
        switch voiceChannel?.state {
        case .incoming?: return true
        default: return false
        }
    }
    
    @objc static let maxVideoCallParticipants: Int = 4

    var canStartVideoCall: Bool {
        guard !isCallOngoing else { return false }

        if self.conversationType == .oneOnOne {
            return true
        }

        if self.conversationType == .group &&
            ZMUser.selfUser().isTeamMember &&
            isConversationEligibleForVideoCalls {
            return true
        }

        return false
    }

    var isConversationEligibleForVideoCalls: Bool {
        return self.activeParticipants.count <= ZMConversation.maxVideoCallParticipants
    }

    var isCallOngoing: Bool {
        switch voiceChannel?.state {
        case .none?: return false
        default: return true
        }
    }
}
