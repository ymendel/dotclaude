# Class Diagrams

Class diagrams model object-oriented structures and domain models.

## Element Syntax

```
[ClassName]                       — class
[ClassName|attr1;attr2]           — with attributes (semicolon-separated)
[ClassName|attr1;attr2|method()]  — with attributes and methods
[<<Interface>>;Name]              — stereotype
[note: text{bg:wheat}]            — annotated note
// comment                        — inline comment
```

## Relationship Types

```
[A]->[B]          — directed association
[A]<->[B]         — bidirectional
[Parent]^[Child]  — inheritance — the side adjacent to ^ is the PARENT
[A]<>[B]          — aggregation
[A]++->[B]        — composition
[A]-.->[B]        — dependency (dashed)
[A]^-.-[B]        — implements (dashed inheritance)
```

**Inheritance direction**: `[Animal]^[Duck]` means Duck inherits from Animal.
When translating from Mermaid (`Animal <|-- Duck`) or PlantUML, both become `[Animal]^[Duck]`.

## Labels and Cardinality

```
[A]label->[B]         — labelled association
[A]orders>*[B]        — label with inline cardinality shorthand
[A]1-0..*>[B]         — explicit cardinality on both ends
```

## Examples

### Domain model

```
[Customer|name;email]-orders>*[Order|date;total]
[Order]->*[LineItem|qty;price]
[LineItem]->[Product|name;sku;price]
```

### Inheritance hierarchy

```
[Animal|age;gender|isMammal();mate()]
[Animal]^[Duck|beakColor|swim();quack()]
[Animal]^[Fish|sizeInFeet|canEat()]
[Animal]^[Zebra|isWild|run()]
```

### Mixed relationships

```
[Company|name|hire()]
[Company]<>[Department|budget]
[Department]++[Employee|salary|work()]
[Employee]-works on->[Project|deadline]
```

### Interface implementation

```
[<<IRepository>>]^-.-[UserRepository]
[<<IRepository>>]^-.-[OrderRepository]
```

## Tips

- Semicolons separate attributes and methods within a section; pipes (`|`) separate sections
- Stereotypes go before the class name: `[<<Interface>>;Name]`
- Notes take optional background colour: `[note: text{bg:wheat}]`
