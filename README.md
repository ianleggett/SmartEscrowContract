# SmartEscrowContract
Creating a benchmark contract for Escrow payments

## Statechart
[![](https://mermaid.ink/img/eyJjb2RlIjoic3RhdGVEaWFncmFtLXYyXG4gICAgWypdIC0tPiBVbmtub3duICAgIFxuICAgIFVua25vd24gLS0-IENyZWF0ZWQ6IG93bmVyXG4gICAgQ3JlYXRlZCAtLT4gQWdyZWVkOiBidXllclxuICAgIEFncmVlZCAtLT4gRGVwb3NpdDogYnV5ZXJcbiAgICBEZXBvc2l0IC0tPiBHb29kc1NlbnQ6IHNlbGxlclxuICAgIEdvb2RzU2VudCAtLT4gR29vZHNSZWNlaXZlZDogYnV5ZXJcbiAgICBHb29kc1JlY2VpdmVkIC0tPiBDb21wbGV0ZWQ6IHNlbGxlci9vd25lclxuICAgIENvbXBsZXRlZCAtLT4gWypdXG4gICAgQWdyZWVkIC0tPiBDYW5jZWw6IGJ1eWVyL3NlbGxlclxuICAgIENhbmNlbCAtLT4gQ2FuY2VsQWdyZWVkOiBidXllci9zZWxsZXJcbiAgICBDYW5jZWxBZ3JlZWQgLS0-IFJlZnVuZGVkOiBvd25lclxuICAgIENhbmNlbCAtLT4gQXJiaXRyYXRpb246IG93bmVyIiwibWVybWFpZCI6eyJ0aGVtZSI6ImRlZmF1bHQifSwidXBkYXRlRWRpdG9yIjpmYWxzZX0)](https://mermaid-js.github.io/mermaid-live-editor/#/edit/eyJjb2RlIjoic3RhdGVEaWFncmFtLXYyXG4gICAgWypdIC0tPiBVbmtub3duICAgIFxuICAgIFVua25vd24gLS0-IENyZWF0ZWQ6IG93bmVyXG4gICAgQ3JlYXRlZCAtLT4gQWdyZWVkOiBidXllclxuICAgIEFncmVlZCAtLT4gRGVwb3NpdDogYnV5ZXJcbiAgICBEZXBvc2l0IC0tPiBHb29kc1NlbnQ6IHNlbGxlclxuICAgIEdvb2RzU2VudCAtLT4gR29vZHNSZWNlaXZlZDogYnV5ZXJcbiAgICBHb29kc1JlY2VpdmVkIC0tPiBDb21wbGV0ZWQ6IHNlbGxlci9vd25lclxuICAgIENvbXBsZXRlZCAtLT4gWypdXG4gICAgQWdyZWVkIC0tPiBDYW5jZWw6IGJ1eWVyL3NlbGxlclxuICAgIENhbmNlbCAtLT4gQ2FuY2VsQWdyZWVkOiBidXllci9zZWxsZXJcbiAgICBDYW5jZWxBZ3JlZWQgLS0-IFJlZnVuZGVkOiBvd25lclxuICAgIENhbmNlbCAtLT4gQXJiaXRyYXRpb246IG93bmVyIiwibWVybWFpZCI6eyJ0aGVtZSI6ImRlZmF1bHQifSwidXBkYXRlRWRpdG9yIjpmYWxzZX0)

stateDiagram-v2
    [*] --> Unknown    
    Unknown --> Created: owner
    Created --> Agreed: buyer
    Agreed --> Deposit: buyer
    Deposit --> GoodsSent: seller
    GoodsSent --> GoodsReceived: buyer
    GoodsReceived --> Completed: seller/owner
    Completed --> [*]
    Agreed --> Cancel: buyer/seller
    Cancel --> CancelAgreed: buyer/seller
    CancelAgreed --> Refunded: owner
    Cancel --> Arbitration: owner
