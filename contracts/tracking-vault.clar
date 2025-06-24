;; tracking-vault
;; 
;; A comprehensive asset tracking and verification system on the Stacks blockchain
;; Enables secure registration, transfer, and lifecycle management of digital and physical assets

;; Error Codes: Centralized error handling for contract operations
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-RESOURCE-MISSING (err u101))
(define-constant ERR-VALIDATION-FAILED (err u102))
(define-constant ERR-ALREADY-PROCESSED (err u103))
(define-constant ERR-TRANSFER-BLOCKED (err u104))
(define-constant ERR-INVALID-RECIPIENT (err u105))
(define-constant ERR-UNAUTHORIZED-ATTESTATION (err u106))

;; Global Asset Tracking Variables
(define-data-var global-asset-counter uint u0)

;; Asset Management Data Structures
(define-map registered-assets
  { asset-id: uint }
  {
    owner: principal,
    description: (string-ascii 256),
    value: uint,
    acquisition-date: uint,
    condition: (string-ascii 64),
    metadata-uri: (optional (string-utf8 256)),
    is-active: bool
  }
)

;; Ownership Transfer History Tracking
(define-map asset-ownership-log
  { asset-id: uint, index: uint }
  {
    previous-owner: principal,
    new-owner: principal,
    transfer-timestamp: uint,
    transfer-notes: (optional (string-ascii 256))
  }
)

;; Ownership Transfer Tracking Counter
(define-map ownership-log-counter
  { asset-id: uint }
  { total-transfers: uint }
)

;; Third-Party Attestation Tracking
(define-map asset-verifications
  { asset-id: uint, index: uint }
  {
    verifier: principal,
    verification-type: (string-ascii 64),
    verification-date: uint,
    verification-details: (string-utf8 256),
    verification-uri: (optional (string-utf8 256))
  }
)

;; Verification Tracking Counter
(define-map verification-counter
  { asset-id: uint }
  { total-verifications: uint }
)

;; Owner's Asset Portfolio Tracking
(define-map principal-asset-portfolio
  { owner: principal }
  { owned-assets: (list 100 uint) }
)

;; Private Helper Functions

;; Generate a unique, incrementing asset identifier
(define-private (generate-unique-asset-id)
  (let ((current-id (var-get global-asset-counter)))
    (var-set global-asset-counter (+ current-id u1))
    current-id
  )
)

;; Record ownership transfer in historical log
(define-private (log-ownership-transfer 
                 (asset-id uint) 
                 (previous-owner principal) 
                 (new-owner principal) 
                 (transfer-notes (optional (string-ascii 256))))
  (let ((current-counter (default-to { total-transfers: u0 } 
                           (map-get? ownership-log-counter { asset-id: asset-id })))
        (transfer-index (get total-transfers current-counter)))
    
    ;; Log transfer details
    (map-set asset-ownership-log
      { asset-id: asset-id, index: transfer-index }
      {
        previous-owner: previous-owner,
        new-owner: new-owner,
        transfer-timestamp: block-height,
        transfer-notes: transfer-notes
      }
    )
    
    ;; Update transfer counter
    (map-set ownership-log-counter
      { asset-id: asset-id }
      { total-transfers: (+ transfer-index u1) }
    )
  )
)

;; Verify if a principal is the current asset owner
(define-private (is-current-owner (asset-id uint) (user principal))
  (let ((asset-record (map-get? registered-assets { asset-id: asset-id })))
    (and
      (is-some asset-record)
      (is-eq user (get owner (unwrap-panic asset-record)))
    )
  )
)

;; Read-Only Query Functions

;; Retrieve details for a specific asset
(define-read-only (get-asset-details (asset-id uint))
  (map-get? registered-assets { asset-id: asset-id })
)

;; List assets owned by a specific principal
(define-read-only (get-owner-assets (owner principal))
  (default-to { owned-assets: (list) } 
    (map-get? principal-asset-portfolio { owner: owner }))
)

;; Retrieve total number of ownership transfers for an asset
(define-read-only (get-transfer-count (asset-id uint))
  (default-to { total-transfers: u0 } 
    (map-get? ownership-log-counter { asset-id: asset-id }))
)

;; Retrieve a specific ownership transfer record
(define-read-only (get-transfer-record (asset-id uint) (transfer-index uint))
  (map-get? asset-ownership-log 
    { asset-id: asset-id, index: transfer-index })
)

;; Determine total verification count for an asset
(define-read-only (get-verification-count (asset-id uint))
  (default-to { total-verifications: u0 } 
    (map-get? verification-counter { asset-id: asset-id }))
)

;; Retrieve a specific verification record
(define-read-only (get-verification-record (asset-id uint) (verification-index uint))
  (map-get? asset-verifications 
    { asset-id: asset-id, index: verification-index })
)

;; Confirm asset's existence
(define-read-only (verify-asset-existence (asset-id uint))
  (is-some (map-get? registered-assets { asset-id: asset-id }))
)

;; Public Interaction Functions

;; Modify asset metadata (restricted to current owner)
(define-public (update-asset-details
                (asset-id uint)
                (description (string-ascii 256))
                (value uint)
                (condition (string-ascii 64))
                (metadata-uri (optional (string-utf8 256))))
  (let ((current-asset (map-get? registered-assets { asset-id: asset-id })))
    ;; Validate asset existence
    (asserts! (is-some current-asset) ERR-RESOURCE-MISSING)
    
    ;; Verify ownership
    (asserts! (is-current-owner asset-id tx-sender) ERR-UNAUTHORIZED)
    
    ;; Input validation
    (asserts! (> (len description) u0) ERR-VALIDATION-FAILED)
    (asserts! (> value u0) ERR-VALIDATION-FAILED)
    
    ;; Update asset record
    (map-set registered-assets
      { asset-id: asset-id }
      (merge (unwrap-panic current-asset)
        {
          description: description,
          value: value,
          condition: condition,
          metadata-uri: metadata-uri
        }
      )
    )
    
    (ok true)
  )
)

;; Add third-party verification/attestation
(define-public (add-asset-verification
                (asset-id uint)
                (verification-type (string-ascii 64))
                (verification-details (string-utf8 256))
                (verification-uri (optional (string-utf8 256))))
  (let ((current-asset (map-get? registered-assets { asset-id: asset-id }))
        (current-counter (default-to { total-verifications: u0 } 
                           (map-get? verification-counter { asset-id: asset-id })))
        (verification-index (get total-verifications current-counter)))
    
    ;; Validate asset existence
    (asserts! (is-some current-asset) ERR-RESOURCE-MISSING)
    
    ;; Validate verification inputs
    (asserts! (> (len verification-type) u0) ERR-VALIDATION-FAILED)
    (asserts! (> (len verification-details) u0) ERR-VALIDATION-FAILED)
    
    ;; Record verification
    (map-set asset-verifications
      { asset-id: asset-id, index: verification-index }
      {
        verifier: tx-sender,
        verification-type: verification-type,
        verification-date: block-height,
        verification-details: verification-details,
        verification-uri: verification-uri
      }
    )
    
    ;; Update verification counter
    (map-set verification-counter
      { asset-id: asset-id }
      { total-verifications: (+ verification-index u1) }
    )
    
    (ok verification-index)
  )
)

;; Deactivate an asset (mark as inactive)
(define-public (deactivate-asset
                (asset-id uint)
                (deactivation-reason (string-ascii 256)))
  (let ((current-asset (map-get? registered-assets { asset-id: asset-id })))
    ;; Validate asset existence
    (asserts! (is-some current-asset) ERR-RESOURCE-MISSING)
    
    ;; Verify ownership
    (asserts! (is-current-owner asset-id tx-sender) ERR-UNAUTHORIZED)
    
    ;; Update asset status
    (map-set registered-assets
      { asset-id: asset-id }
      (merge (unwrap-panic current-asset) { is-active: false })
    )
    
    ;; Log deactivation in ownership history
    (log-ownership-transfer 
      asset-id 
      tx-sender 
      tx-sender 
      (some deactivation-reason)
    )
    
    (ok true)
  )
)

;; Reactivate a previously deactivated asset
(define-public (reactivate-asset
                (asset-id uint)
                (reactivation-reason (string-ascii 256)))
  (let ((current-asset (map-get? registered-assets { asset-id: asset-id })))
    ;; Validate asset existence
    (asserts! (is-some current-asset) ERR-RESOURCE-MISSING)
    
    ;; Verify ownership
    (asserts! (is-current-owner asset-id tx-sender) ERR-UNAUTHORIZED)
    
    ;; Update asset status
    (map-set registered-assets
      { asset-id: asset-id }
      (merge (unwrap-panic current-asset) { is-active: true })
    )
    
    ;; Log reactivation in ownership history
    (log-ownership-transfer 
      asset-id 
      tx-sender 
      tx-sender 
      (some reactivation-reason)
    )
    
    (ok true)
  )
)