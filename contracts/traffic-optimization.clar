;; Traffic Optimization Contract
;; Manages traffic flow efficiency and congestion

(define-map traffic-zones
  { zone-id: (string-ascii 32) }
  {
    max-capacity: uint,
    current-vehicles: uint,
    congestion-level: uint,
    speed-limit: uint,
    last-updated: uint
  }
)

(define-map vehicle-positions
  { vehicle-id: (string-ascii 64) }
  {
    current-zone: (string-ascii 32),
    speed: uint,
    last-update: uint,
    next-zone: (optional (string-ascii 32))
  }
)

(define-map optimization-suggestions
  { zone-id: (string-ascii 32) }
  {
    suggested-speed: uint,
    alternative-routes: (list 5 (string-ascii 32)),
    priority-level: uint
  }
)

;; Error codes
(define-constant ERR-ZONE-NOT-FOUND (err u300))
(define-constant ERR-ZONE-FULL (err u301))
(define-constant ERR-INVALID-SPEED (err u302))

;; Initialize traffic zone
(define-public (init-traffic-zone (zone-id (string-ascii 32))
                                 (max-capacity uint)
                                 (speed-limit uint))
  (begin
    (map-set traffic-zones
      { zone-id: zone-id }
      {
        max-capacity: max-capacity,
        current-vehicles: u0,
        congestion-level: u0,
        speed-limit: speed-limit,
        last-updated: block-height
      }
    )
    (ok zone-id)
  )
)

;; Update vehicle position
(define-public (update-vehicle-position (vehicle-id (string-ascii 64))
                                       (zone-id (string-ascii 32))
                                       (speed uint))
  (let ((zone (unwrap! (map-get? traffic-zones { zone-id: zone-id }) ERR-ZONE-NOT-FOUND)))
    (if (<= speed (get speed-limit zone))
      (begin
        ;; Update vehicle position
        (map-set vehicle-positions
          { vehicle-id: vehicle-id }
          {
            current-zone: zone-id,
            speed: speed,
            last-update: block-height,
            next-zone: none
          }
        )
        ;; Update zone vehicle count
        (map-set traffic-zones
          { zone-id: zone-id }
          (merge zone {
            current-vehicles: (+ (get current-vehicles zone) u1),
            last-updated: block-height
          })
        )
        (ok true)
      )
      ERR-INVALID-SPEED
    )
  )
)

;; Calculate congestion level
(define-public (update-congestion (zone-id (string-ascii 32)))
  (let ((zone (unwrap! (map-get? traffic-zones { zone-id: zone-id }) ERR-ZONE-NOT-FOUND)))
    (let ((congestion (/ (* (get current-vehicles zone) u100) (get max-capacity zone))))
      (map-set traffic-zones
        { zone-id: zone-id }
        (merge zone {
          congestion-level: congestion,
          last-updated: block-height
        })
      )
      (ok congestion)
    )
  )
)

;; Get optimization suggestion
(define-public (get-optimization (zone-id (string-ascii 32)))
  (let ((zone (unwrap! (map-get? traffic-zones { zone-id: zone-id }) ERR-ZONE-NOT-FOUND)))
    (let ((congestion (get congestion-level zone)))
      (if (> congestion u80)
        (begin
          (map-set optimization-suggestions
            { zone-id: zone-id }
            {
              suggested-speed: (- (get speed-limit zone) u10),
              alternative-routes: (list "alt-route-1" "alt-route-2"),
              priority-level: u3
            }
          )
          (ok "high-congestion")
        )
        (ok "normal-flow")
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-traffic-zone (zone-id (string-ascii 32)))
  (map-get? traffic-zones { zone-id: zone-id })
)

(define-read-only (get-vehicle-position (vehicle-id (string-ascii 64)))
  (map-get? vehicle-positions { vehicle-id: vehicle-id })
)

(define-read-only (get-zone-congestion (zone-id (string-ascii 32)))
  (match (map-get? traffic-zones { zone-id: zone-id })
    zone (get congestion-level zone)
    u0
  )
)
