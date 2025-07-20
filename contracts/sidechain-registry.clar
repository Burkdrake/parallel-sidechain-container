;; Parallel Sidechain Container - Sidechain Registry
;; 
;; This contract manages cross-chain interactions and registration 
;; of parallel sidechains within a decentralized ecosystem.
;; 
;; The contract enables secure sidechain tracking, validation, 
;; and interoperability across different blockchain networks.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SIDECHAIN-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PARAMS (err u103))
(define-constant ERR-REGISTRATION-FAILED (err u104))

;; Sidechain Status Enum
(define-constant STATUS-PENDING u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-INACTIVE u2)

;; Data Maps
;; Registry for tracking registered sidechains
(define-map sidechain-registry 
  { sidechain-id: (string-ascii 36) }
  {
    name: (string-utf8 64),
    owner: principal,
    network-type: (string-ascii 32),
    consensus-mechanism: (string-ascii 32),
    status: uint,
    registered-at: uint,
    metadata-uri: (optional (string-utf8 256))
  }
)

;; Track cross-chain verification proofs
(define-map verification-proofs
  { sidechain-id: (string-ascii 36), proof-id: (string-ascii 36) }
  {
    validator: principal,
    verified-at: uint,
    proof-hash: (buff 32),
    is-valid: bool
  }
)

;; Private Functions
;; Validates sidechain registration parameters
(define-private (validate-sidechain-params 
    (name (string-utf8 64))
    (network-type (string-ascii 32))
    (consensus-mechanism (string-ascii 32))
  )
  (and 
    (> (len name) u0)
    (> (len network-type) u0)
    (> (len consensus-mechanism) u0)
  )
)

;; Read-only Functions
;; Retrieve sidechain details
(define-read-only (get-sidechain (sidechain-id (string-ascii 36)))
  (map-get? sidechain-registry { sidechain-id: sidechain-id })
)

;; Check if a sidechain is active
(define-read-only (is-sidechain-active (sidechain-id (string-ascii 36)))
  (match (map-get? sidechain-registry { sidechain-id: sidechain-id })
    sidechain (is-eq (get status sidechain) STATUS-ACTIVE)
    false
  )
)

;; Public Functions
;; Register a new sidechain
(define-public (register-sidechain 
    (sidechain-id (string-ascii 36))
    (name (string-utf8 64))
    (network-type (string-ascii 32))
    (consensus-mechanism (string-ascii 32))
    (metadata-uri (optional (string-utf8 256)))
  )
  (let (
    (caller tx-sender)
    (current-time block-height)
  )
    ;; Validate input parameters
    (asserts! 
      (validate-sidechain-params name network-type consensus-mechanism)
      ERR-INVALID-PARAMS
    )
    
    ;; Check if sidechain already exists
    (asserts! 
      (is-none (map-get? sidechain-registry { sidechain-id: sidechain-id }))
      ERR-ALREADY-EXISTS
    )
    
    ;; Register sidechain
    (map-set sidechain-registry
      { sidechain-id: sidechain-id }
      {
        name: name,
        owner: caller,
        network-type: network-type,
        consensus-mechanism: consensus-mechanism,
        status: STATUS-PENDING,
        registered-at: current-time,
        metadata-uri: metadata-uri
      }
    )
    
    (ok true)
  )
)

;; Update sidechain status
(define-public (update-sidechain-status 
    (sidechain-id (string-ascii 36))
    (new-status uint)
  )
  (let (
    (caller tx-sender)
    (sidechain-info (unwrap! 
      (map-get? sidechain-registry { sidechain-id: sidechain-id }) 
      ERR-SIDECHAIN-NOT-FOUND
    ))
  )
    ;; Ensure caller is the sidechain owner
    (asserts! 
      (is-eq (get owner sidechain-info) caller)
      ERR-NOT-AUTHORIZED
    )
    
    ;; Validate new status
    (asserts! 
      (or 
        (is-eq new-status STATUS-ACTIVE)
        (is-eq new-status STATUS-INACTIVE)
      )
      ERR-INVALID-PARAMS
    )
    
    ;; Update sidechain status
    (map-set sidechain-registry
      { sidechain-id: sidechain-id }
      (merge sidechain-info { status: new-status })
    )
    
    (ok true)
  )
)

;; Submit cross-chain verification proof
(define-public (submit-verification-proof 
    (sidechain-id (string-ascii 36))
    (proof-id (string-ascii 36))
    (proof-hash (buff 32))
  )
  (let (
    (caller tx-sender)
    (current-time block-height)
    (sidechain-info (unwrap! 
      (map-get? sidechain-registry { sidechain-id: sidechain-id }) 
      ERR-SIDECHAIN-NOT-FOUND
    ))
  )
    ;; Ensure sidechain is active
    (asserts! 
      (is-eq (get status sidechain-info) STATUS-ACTIVE)
      ERR-REGISTRATION-FAILED
    )
    
    ;; Record verification proof
    (map-set verification-proofs
      { sidechain-id: sidechain-id, proof-id: proof-id }
      {
        validator: caller,
        verified-at: current-time,
        proof-hash: proof-hash,
        is-valid: true  ;; Initially assumed valid
      }
    )
    
    (ok true)
  )
)