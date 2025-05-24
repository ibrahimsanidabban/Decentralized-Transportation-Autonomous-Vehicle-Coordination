;; Incident Response Contract
;; Manages emergency situations and coordinated responses

(define-map emergency-incidents
  { incident-id: (string-ascii 64) }
  {
    reporter-vehicle: (string-ascii 64),
    incident-type: (string-ascii 32),
    severity-level: uint,
    location: (string-ascii 64),
    affected-vehicles: (list 10 (string-ascii 64)),
    response-status: (string-ascii 16),
    created-at: uint,
    resolved-at: (optional uint)
  }
)

(define-map response-teams
  { team-id: (string-ascii 32) }
  {
    team-type: (string-ascii 32),
    available: bool,
    current-location: (string-ascii 64),
    response-time: uint
  }
)

(define-map incident-responses
  { incident-id: (string-ascii 64), responder-id: (string-ascii 32) }
  {
    response-type: (string-ascii 32),
    dispatched-at: uint,
    arrived-at: (optional uint),
    status: (string-ascii 16)
  }
)

(define-data-var emergency-counter uint u0)
(define-data-var authorized-dispatcher principal tx-sender)

;; Error codes
(define-constant ERR-INCIDENT-NOT-FOUND (err u500))
(define-constant ERR-TEAM-NOT-AVAILABLE (err u501))
(define-constant ERR-NOT-AUTHORIZED (err u502))
(define-constant ERR-INVALID-SEVERITY (err u503))

;; Report emergency incident
(define-public (report-emergency (reporter-vehicle (string-ascii 64))
                                (incident-type (string-ascii 32))
                                (severity-level uint)
                                (location (string-ascii 64))
                                (affected-vehicles (list 10 (string-ascii 64))))
  (let ((incident-id (int-to-ascii (var-get emergency-counter))))
    (if (<= severity-level u5)
      (begin
        (map-set emergency-incidents
          { incident-id: incident-id }
          {
            reporter-vehicle: reporter-vehicle,
            incident-type: incident-type,
            severity-level: severity-level,
            location: location,
            affected-vehicles: affected-vehicles,
            response-status: "reported",
            created-at: block-height,
            resolved-at: none
          }
        )
        (var-set emergency-counter (+ (var-get emergency-counter) u1))
        (ok incident-id)
      )
      ERR-INVALID-SEVERITY
    )
  )
)

;; Register response team
(define-public (register-response-team (team-id (string-ascii 32))
                                      (team-type (string-ascii 32))
                                      (location (string-ascii 64))
                                      (response-time uint))
  (begin
    (map-set response-teams
      { team-id: team-id }
      {
        team-type: team-type,
        available: true,
        current-location: location,
        response-time: response-time
      }
    )
    (ok team-id)
  )
)

;; Dispatch response team
(define-public (dispatch-team (incident-id (string-ascii 64))
                             (team-id (string-ascii 32))
                             (response-type (string-ascii 32)))
  (let ((incident (unwrap! (map-get? emergency-incidents { incident-id: incident-id }) ERR-INCIDENT-NOT-FOUND))
        (team (unwrap! (map-get? response-teams { team-id: team-id }) ERR-TEAM-NOT-AVAILABLE)))
    (if (get available team)
      (begin
        ;; Mark team as unavailable
        (map-set response-teams
          { team-id: team-id }
          (merge team { available: false })
        )
        ;; Create response record
        (map-set incident-responses
          { incident-id: incident-id, responder-id: team-id }
          {
            response-type: response-type,
            dispatched-at: block-height,
            arrived-at: none,
            status: "dispatched"
          }
        )
        ;; Update incident status
        (map-set emergency-incidents
          { incident-id: incident-id }
          (merge incident { response-status: "responding" })
        )
        (ok true)
      )
      ERR-TEAM-NOT-AVAILABLE
    )
  )
)

;; Mark team arrival
(define-public (mark-arrival (incident-id (string-ascii 64)) (team-id (string-ascii 32)))
  (match (map-get? incident-responses { incident-id: incident-id, responder-id: team-id })
    response (begin
               (map-set incident-responses
                 { incident-id: incident-id, responder-id: team-id }
                 (merge response {
                   arrived-at: (some block-height),
                   status: "on-scene"
                 })
               )
               (ok true))
    ERR-INCIDENT-NOT-FOUND
  )
)

;; Resolve incident
(define-public (resolve-emergency (incident-id (string-ascii 64)))
  (match (map-get? emergency-incidents { incident-id: incident-id })
    incident (begin
               (map-set emergency-incidents
                 { incident-id: incident-id }
                 (merge incident {
                   response-status: "resolved",
                   resolved-at: (some block-height)
                 })
               )
               (ok true))
    ERR-INCIDENT-NOT-FOUND
  )
)

;; Read-only functions
(define-read-only (get-emergency-incident (incident-id (string-ascii 64)))
  (map-get? emergency-incidents { incident-id: incident-id })
)

(define-read-only (get-response-team (team-id (string-ascii 32)))
  (map-get? response-teams { team-id: team-id })
)

(define-read-only (get-incident-response (incident-id (string-ascii 64)) (team-id (string-ascii 32)))
  (map-get? incident-responses { incident-id: incident-id, responder-id: team-id })
)

(define-read-only (is-team-available (team-id (string-ascii 32)))
  (match (map-get? response-teams { team-id: team-id })
    team (get available team)
    false
  )
)
