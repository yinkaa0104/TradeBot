;; Tactical: Gamified Trading Competition Platform
;; A Clarity smart contract for decentralized trading competitions on Stacks

;; Constants
(define-constant STARTING-BALANCE u10000000)
(define-constant MIN-POSITION-SIZE u100000)
(define-constant MAX-LEVERAGE u10)
(define-constant MAX-POSITIONS u100)
(define-constant COMPETITION-DURATION u144000)
(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-ALREADY-JOINED u2)
(define-constant ERR-NOT-JOINED u3)
(define-constant ERR-INSUFFICIENT-BALANCE u4)
(define-constant ERR-INVALID-SIZE u5)
(define-constant ERR-POSITION-NOT-FOUND u6)
(define-constant ERR-INVALID-LEVERAGE u7)
(define-constant ERR-COMPETITION-ENDED u8)
(define-constant ERR-NO-PRIZES u9)
(define-constant ERR-INVALID-DIRECTION u10)
(define-constant ERR-POSITION-NOT-OPEN u11)
(define-constant ERR-LEADERBOARD-NOT-FOUND u12)
(define-constant ERR-TRADER-NOT-FOUND u13)

;; Data Maps
(define-map traders
  { trader: principal }
  {
    balance: uint,
    total-positions: uint,
    realized-pnl: int,
    win-count: uint,
    loss-count: uint,
    join-block: uint,
    active: bool
  }
)

(define-map positions
  { trader: principal, position-id: uint }
  {
    asset: (string-ascii 10),
    direction: (string-ascii 5),
    entry-price: uint,
    exit-price: (optional uint),
    size: uint,
    leverage: uint,
    opened-at: uint,
    closed-at: (optional uint),
    is-open: bool,
    pnl: int
  }
)

(define-map leaderboard
  { trader: principal }
  {
    total-pnl: int,
    roi: int,
    rank: uint
  }
)

;; State Variables
(define-data-var competition-active bool true)
(define-data-var competition-start-block uint block-height)
(define-data-var prize-pool uint u0)
(define-data-var total-traders uint u0)
(define-data-var position-counter uint u0)

;; Join competition with starting capital
(define-public (join-competition)
  (let
    (
      (caller tx-sender)
      (existing-trader (map-get? traders { trader: caller }))
    )
    (asserts! (var-get competition-active) (err ERR-COMPETITION-ENDED))
    (asserts! (is-none existing-trader) (err ERR-ALREADY-JOINED))

    (map-insert traders
      { trader: caller }
      {
        balance: STARTING-BALANCE,
        total-positions: u0,
        realized-pnl: 0,
        win-count: u0,
        loss-count: u0,
        join-block: block-height,
        active: true
      }
    )

    (map-insert leaderboard
      { trader: caller }
      {
        total-pnl: 0,
        roi: 0,
        rank: u0
      }
    )

    (var-set total-traders (+ (var-get total-traders) u1))
    (ok true)
  )
)

;; Open a new position
(define-public (open-position (asset (string-ascii 10)) (direction (string-ascii 5)) (entry-price uint) (size uint) (leverage uint))
  (let
    (
      (caller tx-sender)
      (trader-data (map-get? traders { trader: caller }))
      (margin-required (/ (* size leverage) u1000000))
      (new-position-id (var-get position-counter))
    )
    (asserts! (is-some trader-data) (err ERR-NOT-JOINED))
    (asserts! (var-get competition-active) (err ERR-COMPETITION-ENDED))
    (asserts! (or (is-eq direction "long") (is-eq direction "short")) (err ERR-INVALID-DIRECTION))
    (asserts! (>= size MIN-POSITION-SIZE) (err ERR-INVALID-SIZE))
    (asserts! (and (> leverage u0) (<= leverage MAX-LEVERAGE)) (err ERR-INVALID-LEVERAGE))

    (let ((trader-unwrap (unwrap! trader-data (err ERR-TRADER-NOT-FOUND))))
      (asserts! (>= (get balance trader-unwrap) margin-required) (err ERR-INSUFFICIENT-BALANCE))

      (map-insert positions
        { trader: caller, position-id: new-position-id }
        {
          asset: asset,
          direction: direction,
          entry-price: entry-price,
          exit-price: none,
          size: size,
          leverage: leverage,
          opened-at: block-height,
          closed-at: none,
          is-open: true,
          pnl: 0
        }
      )

      (map-set traders
        { trader: caller }
        (merge trader-unwrap {
          balance: (- (get balance trader-unwrap) margin-required),
          total-positions: (+ (get total-positions trader-unwrap) u1)
        })
      )

      (var-set position-counter (+ new-position-id u1))
      (ok new-position-id)
    )
  )
)

;; Close a position and realize PnL
(define-public (close-position (position-id uint) (exit-price uint))
  (let
    (
      (caller tx-sender)
      (position-data (map-get? positions { trader: caller, position-id: position-id }))
      (trader-data (map-get? traders { trader: caller }))
    )
    (asserts! (is-some position-data) (err ERR-POSITION-NOT-FOUND))
    (asserts! (is-some trader-data) (err ERR-NOT-JOINED))

    (let
      (
        (pos (unwrap! position-data (err ERR-POSITION-NOT-FOUND)))
        (trader (unwrap! trader-data (err ERR-TRADER-NOT-FOUND)))
      )
      (asserts! (get is-open pos) (err ERR-POSITION-NOT-OPEN))

      (let
        (
          (pnl (calculate-pnl (get direction pos) (get entry-price pos) exit-price (get size pos) (get leverage pos)))
          (margin-freed (/ (* (get size pos) (get leverage pos)) u1000000))
          (is-win (> pnl 0))
        )
        (map-set positions
          { trader: caller, position-id: position-id }
          (merge pos {
            exit-price: (some exit-price),
            closed-at: (some block-height),
            is-open: false,
            pnl: pnl
          })
        )

        (map-set traders
          { trader: caller }
          (merge trader {
            balance: (+ (get balance trader) margin-freed),
            realized-pnl: (+ (get realized-pnl trader) pnl),
            win-count: (if is-win (+ (get win-count trader) u1) (get win-count trader)),
            loss-count: (if is-win (get loss-count trader) (+ (get loss-count trader) u1))
          })
        )

        (ok pnl)
      )
    )
  )
)

;; End competition (owner only)
(define-public (end-competition)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) (err ERR-NOT-AUTHORIZED))
    (var-set competition-active false)
    (ok true)
  )
)

;; Add to prize pool (owner only)
(define-public (add-prize-pool (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) (err ERR-NOT-AUTHORIZED))
    (var-set prize-pool (+ (var-get prize-pool) amount))
    (ok true)
  )
)

;; Get trader statistics
(define-read-only (get-trader-stats (trader principal))
  (map-get? traders { trader: trader })
)

;; Get position details
(define-read-only (get-position (trader principal) (position-id uint))
  (map-get? positions { trader: trader, position-id: position-id })
)

;; Get leaderboard score
(define-read-only (get-leaderboard-score (trader principal))
  (map-get? leaderboard { trader: trader })
)

;; Calculate ROI percentage
(define-read-only (calculate-roi (trader principal))
  (let ((trader-data (map-get? traders { trader: trader })))
    (match trader-data
      trader-unwrap
      (if (> (get realized-pnl trader-unwrap) 0)
        (ok (/ (* (get realized-pnl trader-unwrap) 100) (to-int STARTING-BALANCE)))
        (ok 0)
      )
      (err ERR-TRADER-NOT-FOUND)
    )
  )
)

;; Get competition status
(define-read-only (get-competition-status)
  (ok {
    active: (var-get competition-active),
    start-block: (var-get competition-start-block),
    current-block: block-height,
    total-traders: (var-get total-traders),
    prize-pool: (var-get prize-pool)
  })
)

;; Calculate PnL based on position direction and prices
(define-private (calculate-pnl (direction (string-ascii 5)) (entry-price uint) (exit-price uint) (size uint) (leverage uint))
  (let
    (
      (price-diff (if (< exit-price entry-price) 
        (- entry-price exit-price) 
        (- exit-price entry-price)
      ))
      (is-profitable (if (is-eq direction "long")
        (> exit-price entry-price)
        (< exit-price entry-price)
      ))
      (leveraged-pnl (/ (* price-diff size leverage) entry-price))
    )
    (if is-profitable
      (to-int leveraged-pnl)
      (- 0 (to-int leveraged-pnl))
    )
  )
)
