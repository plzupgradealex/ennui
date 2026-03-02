import Foundation
import MultipeerConnectivity
import Combine

/// Manages local network sharing with explicit user consent.
///
/// Key principles:
/// - Sharing is OFF by default — the user must opt in
/// - No hostname broadcast — anonymous display names only
/// - No auto-accept — every peer invitation requires user confirmation
/// - Scene sync only — no personal data ever crosses the wire
class MultipeerManager: NSObject, ObservableObject {
    private let serviceType = "ennui-calm"
    private let myPeerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // MARK: - Published state

    /// Whether the user has opted in to sharing
    @Published var isEnabled = false

    /// Peers currently connected
    @Published var connectedPeers: [MCPeerID] = []

    /// Scene received from a connected peer (to be consumed by ContentView)
    @Published var receivedSceneID: String? = nil

    /// A pending invitation waiting for user consent
    @Published var pendingInvitation: PeerInvitation? = nil

    struct PeerInvitation: Identifiable {
        let id = UUID()
        let peerID: MCPeerID
        let handler: (Bool, MCSession?) -> Void
    }

    // MARK: - Init

    override init() {
        // Anonymous display name — never broadcast the user's real name
        let adjectives = ["Quiet", "Gentle", "Calm", "Soft", "Still", "Warm"]
        let nouns = ["Listener", "Observer", "Drifter", "Watcher", "Dreamer"]
        let adj = adjectives[Int.random(in: 0..<adjectives.count)]
        let noun = nouns[Int.random(in: 0..<nouns.count)]
        let tag = Int.random(in: 10...99)
        let displayName = "\(adj) \(noun) #\(tag)"

        myPeerID = MCPeerID(displayName: displayName)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
        // Services NOT started here — user must opt in via startSharing()
    }

    // MARK: - Public API

    /// User opted in — begin advertising and browsing
    func startSharing() {
        guard !isEnabled else { return }
        isEnabled = true

        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    /// User opted out — stop everything and disconnect
    func stopSharing() {
        isEnabled = false
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        session.disconnect()

        DispatchQueue.main.async {
            self.connectedPeers = []
            self.pendingInvitation = nil
        }
    }

    /// Accept the pending peer invitation
    func acceptInvitation() {
        pendingInvitation?.handler(true, session)
        pendingInvitation = nil
    }

    /// Decline the pending peer invitation
    func declineInvitation() {
        pendingInvitation?.handler(false, nil)
        pendingInvitation = nil
    }

    /// Send current scene ID to all connected peers
    func send(sceneID: String) {
        guard !session.connectedPeers.isEmpty,
              let data = sceneID.data(using: .utf8) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    deinit {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
    }
}

// MARK: - MCSessionDelegate

extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Strict validation: only accept known scene IDs
        guard let sceneID = String(data: data, encoding: .utf8),
              SceneKind(rawValue: sceneID) != nil else { return }
        DispatchQueue.main.async {
            self.receivedSceneID = sceneID
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Never auto-accept — always ask the user
        DispatchQueue.main.async {
            // If there's already a pending invitation, decline the new one
            if self.pendingInvitation != nil {
                invitationHandler(false, nil)
                return
            }
            self.pendingInvitation = PeerInvitation(
                peerID: peerID,
                handler: invitationHandler
            )
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
