;; Vehicle Verification Contract
;; Validates and manages autonomous vehicles in the network

(define-map vehicles
  { vehicle-id: (string-ascii 64) }
  {
    owner: principal,
    manufacturer: (string-ascii 32),
    model: (string-ascii 32),
    certification-level: uint,
    is-verified: bool,
    registration-block: uint
  }
)

(define-map vehicle-certifications
  { vehicle-id: (string-ascii 64) }
  {
    safety-score: uint,
    last-inspection: uint,
    certification-expiry: uint
  }
)

(define-data-var contract-owner principal tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-VEHICLE-EXISTS (err u101))
(define-constant ERR-VEHICLE-NOT-FOUND (err u102))
(define-constant ERR-INVALID-CERTIFICATION (err u103))

;; Register a new autonomous vehicle
(define-public (register-vehicle (vehicle-id (string-ascii 64))
                                (manufacturer (string-ascii 32))
                                (model (string-ascii 32))
                                (certification-level uint))
  (let ((existing-vehicle (map-get? vehicles { vehicle-id: vehicle-id })))
    (if (is-some existing-vehicle)
      ERR-VEHICLE-EXISTS
      (begin
        (map-set vehicles
          { vehicle-id: vehicle-id }
          {
            owner: tx-sender,
            manufacturer: manufacturer,
            model: model,
            certification-level: certification-level,
            is-verified: false,
            registration-block: block-height
          }
        )
        (ok vehicle-id)
      )
    )
  )
)

;; Verify a vehicle (only contract owner)
(define-public (verify-vehicle (vehicle-id (string-ascii 64)) (safety-score uint))
  (let ((vehicle (unwrap! (map-get? vehicles { vehicle-id: vehicle-id }) ERR-VEHICLE-NOT-FOUND)))
    (if (is-eq tx-sender (var-get contract-owner))
      (begin
        (map-set vehicles
          { vehicle-id: vehicle-id }
          (merge vehicle { is-verified: true })
        )
        (map-set vehicle-certifications
          { vehicle-id: vehicle-id }
          {
            safety-score: safety-score,
            last-inspection: block-height,
            certification-expiry: (+ block-height u52560) ;; ~1 year
          }
        )
        (ok true)
      )
      ERR-NOT-AUTHORIZED
    )
  )
)

;; Get vehicle information
(define-read-only (get-vehicle (vehicle-id (string-ascii 64)))
  (map-get? vehicles { vehicle-id: vehicle-id })
)

;; Check if vehicle is verified
(define-read-only (is-vehicle-verified (vehicle-id (string-ascii 64)))
  (match (map-get? vehicles { vehicle-id: vehicle-id })
    vehicle (get is-verified vehicle)
    false
  )
)

;; Get vehicle certification
(define-read-only (get-vehicle-certification (vehicle-id (string-ascii 64)))
  (map-get? vehicle-certifications { vehicle-id: vehicle-id })
)
