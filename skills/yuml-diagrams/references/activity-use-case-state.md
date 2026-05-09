# Activity, Use Case, and State Diagrams

## Activity Diagrams

Model workflows, algorithms, and business processes.

### Syntax

```
(Activity Name)           — activity (rounded box)
(start)                   — start node
(end)                     — end node
<Decision>                — decision diamond
|Fork|                    — fork/join bar (parallel flows)
(A)->(B)                  — flow
(A)label->(B)             — labelled flow
(A)[guard]->(B)           — guarded flow
(note: text)              — note
```

### Example: Order processing

```
(start)->(Receive Order)
(Receive Order)-><Valid?>
<Valid?>[yes]->(Process)
<Valid?>[no]->(Reject)
(Process)->|Ship|
|Ship|->(Pack)
|Ship|->(Label)
(Pack)->(end)
(Label)->(end)
(Reject)->(end)
```

---

## Use Case Diagrams

Model system functionality from a user perspective. Default layout is left-to-right.

### Syntax

```
[Actor Name]       — actor (stick figure)
(Use Case Name)    — use case (ellipse)
[A]-(B)            — association (actor to use case)
(A)<(B)            — extends relationship
(A)>(B)            — includes relationship
(A)^(B)            — inheritance
```

### Example: E-commerce system

```
[Customer]-(Place Order)
[Customer]-(Track Order)
[Customer]-(Return Item)
(Place Order)>(Validate Payment)
(Track Order)<(Cancel Order)
[Admin]-(Manage Inventory)
[Admin]-(Process Refund)
```

### Tips

- Use cases default to LR layout; add `@direction TB` to override
- `>` = includes (always happens), `<` = extends (happens conditionally)

---

## State Diagrams

Model state machines and object lifecycle.

### Syntax

```
[State Name]                        — state (rounded rectangle)
(start)                             — initial state
(end)                               — final state
<Choice>                            — choice diamond
[A]->[B]                            — basic transition
[A]-event->[B]                      — event-triggered transition
[A]-event[guard]->[B]               — guarded transition
[A]-event[guard]/action->[B]        — transition with side effect
[note: text]                        — note
```

### Example: Session lifecycle

```
(start)->[Idle]
[Idle]-login->[Active]
[Active]-logout->[Idle]
[Active]-timeout[inactive > 30m]->[Expired]
[Expired]-renew->[Active]
[Expired]->[Idle]
[Active]-delete->(end)
```

### Example: Order status

```
(start)->[Pending]
[Pending]-pay->[Paid]
[Pending]-cancel->[Cancelled]
[Paid]-ship->[Shipped]
[Shipped]-deliver->[Delivered]
[Delivered]->(end)
[Cancelled]->(end)
```
