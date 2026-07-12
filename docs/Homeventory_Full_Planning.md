# Homeventory
## Full Product and Technical Planning Specification

**Document status:** Initial full-scope planning  
**Primary platform:** Android mobile application  
**Recommended client:** Flutter  
**Recommended backend platform:** Supabase  
**Authentication:** Google SSO  
**Notifications:** In-app notifications and Android push notifications only  
**Primary storage model:** Home → Room → Inventory Node → Nested Inventory Node

---

# 1. Product Summary

Homeventory is a collaborative household inventory application that creates a searchable digital map of everything stored in a home.

The application should help users answer:

1. What do I own?
2. Where is it stored?
3. Who owns it?
4. How many are available?
5. When will it expire?
6. When will it need refilling?
7. When will all remaining stock run out?
8. What has been packed into a suitcase, bag, or other mobile container?
9. Where should packed items be returned after unpacking?
10. Who added, moved, used, restocked, packed, or disposed of an item?

The application supports multiple Homes, shared members, room organization, furniture, nested containers, stock quantities, barcode scanning, predictive consumption, expiration tracking, packing workflows, images, audit history, and notifications.

---

# 2. Product Positioning

Homeventory should not be positioned as only a list of belongings.

A stronger positioning is:

> A searchable digital map of everything in your home—where it is, how much remains, and where it moves.

The product combines:

```text
Household inventory
+ Physical location mapping
+ Consumable tracking
+ Refill and depletion prediction
+ Packing and unpacking
+ Shared household access
```

Core user promise:

```text
Find it.
Track it.
Use it.
Refill it.
Pack it.
Put it back.
```

---

# 3. Primary User Problems

Homeventory should solve practical household questions such as:

- Where is the HDMI cable?
- Which suitcase contains the travel adapter?
- How many laundry pods remain?
- When will the open laundry pod container be empty?
- When will all reserve laundry pods run out?
- Is there another bottle of liquid soap in storage?
- Which items are expiring soon?
- What did I pack for my last business trip?
- Which items have not been unpacked?
- Where should this item be returned?
- Who moved this item?
- Which Home owns this item?
- What belongings are stored at my parents' house?

---

# 4. Scope Principles

## 4.1 Model physical reality

The app represents real physical containment:

```text
Home
└── Room
    └── Furniture or Storage Location
        └── Container
            └── Subcontainer
                └── Item
```

Example:

```text
Bangkok Apartment
└── Bedroom
    └── Wardrobe
        └── Top Shelf
            └── Black Suitcase
                └── Toiletry Bag
                    └── Electric Shaver
```

## 4.2 Items may also be containers

An object may be both:

- An inventory item with price, owner, purchase date, image, weight, and barcode.
- A container holding other objects.

Examples:

- Suitcase.
- Backpack.
- Camera bag.
- Tool bag.
- Wallet.
- Document pouch.
- Storage box.
- Laptop bag.

## 4.3 Inventory changes must be auditable

Stock quantities should not be silently overwritten.

Every quantity-changing action should create an inventory transaction.

## 4.4 Predictions must be explainable

The application should not pretend to know more than the available data supports.

Predictions should include:

- Estimated daily usage.
- Estimated refill date.
- Estimated total depletion date.
- Confidence level.
- Explanation when confidence is low.

## 4.5 Security must be enforced outside the mobile interface

Hiding a button is not authorization.

Access control must be enforced using:

- Supabase authentication.
- PostgreSQL Row Level Security.
- Private storage policies.
- Trusted database functions.
- Supabase Edge Functions where required.

---

# 5. Current Product Decisions

The following decisions are included in this specification:

- Android-first mobile application.
- Flutter client.
- Supabase backend platform.
- Google SSO as the primary authentication method.
- No custom email workflow.
- No magic-link or email-based invitation workflow in the first version.
- In-app notifications and Firebase Cloud Messaging push notifications.
- Recursive inventory-node hierarchy.
- Items may function as containers.
- Packing and unpacking are part of the core product.
- Predictive usage includes both active-container duration and overall stock duration.
- Household messaging is excluded for now.
- Online-first architecture with minimal local caching.
- Private image storage.
- Security-by-design with automated cross-Home authorization testing.

---

# 6. User Types and Roles

## 6.1 Registered User

A registered user may:

- Sign in using Google.
- Create one or more Homes.
- Join one or more Homes.
- Own items.
- Add rooms and inventory according to permissions.
- Receive in-app and push notifications.
- Use the app on multiple devices.

## 6.2 Home Roles

Recommended roles:

```text
OWNER
ADMIN
EDITOR
VIEWER
```

### Owner

Can:

- Edit Home settings.
- Invite members.
- Remove members.
- Assign roles.
- Transfer ownership.
- Archive or delete the Home.
- Manage all rooms and inventory.
- Export Home data.
- Configure security and notification settings.

### Admin

Can:

- Manage rooms.
- Manage inventory.
- Invite members where allowed.
- View audit history.
- Configure operational Home settings.

Cannot:

- Remove the last Owner.
- Transfer ownership without authorization.
- Permanently delete the Home unless explicitly permitted.

### Editor

Can:

- Add and edit items.
- Add furniture and containers.
- Move items and containers.
- Use, restock, refill, pack, and unpack.
- Upload and replace images.
- Scan barcodes.

Cannot:

- Transfer Home ownership.
- Change high-level security settings.
- Remove Owners or Admins.

### Viewer

Can:

- Browse inventory.
- Search.
- View quantities.
- View locations.
- View item history where permitted.

Cannot modify records.

---

# 7. Authentication

## 7.1 Primary Sign-In Method

Homeventory will use Google SSO through Supabase Auth.

User flow:

```text
Open app
→ Continue with Google
→ Select Google account
→ Supabase authenticates user
→ First login creates Homeventory profile
→ Existing login restores Homeventory access
```

## 7.2 First-Time User Creation

On first successful authentication:

1. Supabase creates the authentication identity.
2. Homeventory creates a corresponding profile record.
3. The user completes onboarding.
4. The user may create a Home or accept an in-app invitation.

## 7.3 Profile Model

```text
profiles
- id UUID, matching auth.users.id
- email
- display_name
- avatar_url
- preferred_currency
- preferred_language
- timezone
- created_at
- updated_at
```

## 7.4 Authentication Boundary

Google authentication answers:

```text
Who is this user?
```

Supabase Row Level Security answers:

```text
Which Homes, rooms, items, images, trips, and transactions may this user access?
```

## 7.5 Session Security

- Store Supabase sessions using Android secure storage.
- Protect secrets using Android Keystore.
- Clear local private data on logout.
- Allow device session revocation later.
- Require recent authentication for ownership transfer, export, and account deletion.
- Never place the Supabase service-role key in the APK.

---

# 8. Home Management

A Home is the top-level inventory instance.

Examples:

- Bangkok Apartment.
- Parents' House.
- Office.
- Storage Unit.
- Holiday Home.

## 8.1 Home Fields

```text
homes
- id UUID
- name
- description
- cover_image_id
- address_text nullable
- timezone
- default_currency
- created_by_user_id
- created_at
- updated_at
- archived_at
```

Exact addresses should be optional because household inventory data is sensitive.

## 8.2 Home Actions

- Create Home.
- Edit Home.
- Archive Home.
- Restore Home.
- View Home dashboard.
- Invite member.
- Remove member.
- Change member role.
- Transfer ownership.
- Export inventory.
- View Home activity.

---

# 9. Home Membership

## 9.1 Home Member Model

```text
home_members
- id UUID
- home_id
- user_id
- role
- status
- joined_at
- invited_by_user_id
- removed_at
```

Status values:

```text
PENDING
ACTIVE
REMOVED
LEFT
```

Unique constraint:

```text
home_id + user_id
```

## 9.2 In-App Invitations

Because email is excluded, invitations should be handled through:

- In-app invitation to an existing user.
- Shareable invite link.
- QR invite code.
- Short invite code.

Recommended invitation flow:

```text
Owner creates invitation
→ App generates expiring invite token
→ Owner shares link, QR, or code
→ Recipient signs in with Google
→ Recipient reviews Home and assigned role
→ Recipient accepts
→ Membership becomes active
```

## 9.3 Invitation Security

Invite tokens must be:

- Cryptographically random.
- Single-use.
- Expiring.
- Revocable.
- Stored as hashes.
- Bound to a predefined role.
- Optionally restricted to a known email address.
- Invalid after acceptance.

Invite links must not directly grant access without authentication.

---

# 10. Room Management

Rooms belong to a Home.

Examples:

- Living Room.
- Master Bedroom.
- Kitchen.
- Bathroom.
- Garage.
- Storage Room.
- Office.
- Balcony.

## 10.1 Room Fields

```text
rooms
- id UUID
- home_id
- name
- description
- image_id
- owner_user_id nullable
- sort_order
- created_by_user_id
- created_at
- updated_at
- archived_at
```

## 10.2 Room Functions

- Add room.
- Edit room.
- Upload room image.
- Reorder rooms.
- Add furniture.
- Add container.
- Add item.
- Search within room.
- Assign optional responsible owner.
- Configure room-specific permissions later.

Home permissions should be inherited by rooms by default.

---

# 11. Unified Inventory Node Model

Furniture, storage locations, containers, subcontainers, and items should use one recursive entity:

```text
inventory_nodes
```

## 11.1 Inventory Node Fields

```text
inventory_nodes
- id UUID
- home_id
- room_id
- parent_node_id nullable
- node_kind
- name
- description
- is_container
- is_mobile_container
- item_category nullable
- quantity nullable
- quantity_unit nullable
- minimum_quantity nullable
- purchase_price nullable
- currency nullable
- purchase_date nullable
- expiration_date nullable
- brand nullable
- model nullable
- serial_number nullable
- condition nullable
- weight nullable
- weight_unit nullable
- owner_user_id nullable
- created_by_user_id
- created_at
- updated_at
- archived_at
```

## 11.2 Node Kinds

```text
FURNITURE
STORAGE_LOCATION
ITEM
```

## 11.3 Example Configurations

### Built-In Wardrobe

```text
node_kind = FURNITURE
is_container = true
is_mobile_container = false
```

### Television

```text
node_kind = ITEM
is_container = false
is_mobile_container = false
```

### Suitcase

```text
node_kind = ITEM
is_container = true
is_mobile_container = true
item_category = BAG_LUGGAGE
```

### Storage Box

```text
node_kind = ITEM
is_container = true
is_mobile_container = true
item_category = MISC
```

---

# 12. Containment Rules

- A top-level node belongs directly to a room.
- A nested node belongs to another inventory node.
- Only nodes with `is_container = true` may contain children.
- A node cannot contain itself.
- A node cannot be moved into one of its descendants.
- Parent and child must belong to the same Home.
- The room must belong to the same Home.
- Moving a container moves all descendants with it.
- The system should not impose a fixed nesting depth.
- Archived containers cannot receive new items.
- Users must have edit permission for the destination.
- Trusted backend logic must validate every move.

Example path:

```text
Parents' House
> Master Bedroom
> Wardrobe
> Black Suitcase
> Passport Pouch
> Passport
```

---

# 13. Item Categories

Initial categories:

```text
EDIBLE
CONSUMABLE
CLOTHING
BAG_LUGGAGE
ELECTRONICS
MISC
```

Future categories:

```text
DOCUMENT
MEDICATION
TOOL
APPLIANCE
BOOK
TOY
VALUABLE
COLLECTIBLE
PERSONAL_CARE
CLEANING_PRODUCT
```

Categories should influence available fields but should not require separate tables for every item type.

---

# 14. Category-Specific Attributes

## 14.1 Edible

Optional fields:

```text
expiration_date
opened_date
batch_number
storage_instructions
quantity_unit
```

Examples:

- Milk.
- Rice.
- Frozen meat.
- Snacks.
- Cooking ingredients.

## 14.2 Consumable

Optional fields:

```text
expiration_date
opened_date
minimum_quantity
active_container_support
```

Examples:

- Liquid soap.
- Laundry pods.
- Toothpaste.
- Shampoo.
- Cleaning liquid.
- Batteries.

## 14.3 Clothing

Optional fields:

```text
size
color
material
season
brand
```

## 14.4 Bag or Luggage

Optional fields:

```text
capacity
empty_weight
dimensions
is_mobile_container
```

## 14.5 Electronics

Optional fields:

```text
brand
model
serial_number
warranty_expiration
imei
voltage
condition
```

## 14.6 Miscellaneous

Supports all common fields and user-defined notes.

---

# 15. Quantity and Unit Management

Every stock-tracked item has:

```text
quantity
quantity_unit
minimum_quantity
```

Supported units may include:

```text
PIECE
PAIR
SET
PACK
BOX
BAG
BOTTLE
CAN
POD
ROLL
TUBE
GRAM
KILOGRAM
MILLILITER
LITER
```

Quantity should use decimal storage.

Examples:

```text
Laundry pods:
quantity = 28
unit = POD

Dishwashing liquid:
quantity = 650
unit = MILLILITER

Rice:
quantity = 4.5
unit = KILOGRAM
```

For individually tracked objects:

```text
quantity = 1
unit = PIECE
```

---

# 16. Product and Container Stock Model

Refillable products require two related concepts:

1. Product stock.
2. Physical product containers.

Example:

```text
Liquid Hand Soap
├── Bathroom Dispenser — ACTIVE — 300 mL
├── Refill Pouch 1 — RESERVE — 700 mL
└── Refill Pouch 2 — RESERVE — 500 mL
```

## 16.1 Product Model

```text
products
- id UUID
- home_id
- name
- category
- brand
- default_unit
- barcode_group_id nullable
- created_at
- updated_at
```

## 16.2 Product Container Model

```text
product_containers
- id UUID
- home_id
- product_id
- inventory_node_id
- container_role
- capacity
- current_quantity
- quantity_unit
- opened_at
- created_at
- updated_at
```

Container roles:

```text
ACTIVE
RESERVE
```

An active container is currently being used.

Reserve containers provide future refill stock.

---

# 17. Inventory Transactions

Every quantity or stock movement must create a transaction.

## 17.1 Transaction Types

```text
INITIAL_STOCK
RESTOCK
USE
ADJUSTMENT
TRANSFER
TRANSFER_REFILL
RETURN
DISPOSE
EXPIRED
LOST
FOUND
PACK
UNPACK
```

## 17.2 Transaction Fields

```text
inventory_transactions
- id UUID
- home_id
- inventory_node_id nullable
- product_id nullable
- source_container_id nullable
- destination_container_id nullable
- transaction_type
- quantity_change nullable
- quantity_before nullable
- quantity_after nullable
- quantity_unit nullable
- reason nullable
- performed_by_user_id
- created_at
```

## 17.3 Restock Example

```text
Laundry pods:
20 → 40 pods

transaction_type = RESTOCK
quantity_change = +20
```

## 17.4 Use Example

```text
Laundry pods:
40 → 38 pods

transaction_type = USE
quantity_change = -2
```

## 17.5 Refill Example

```text
Refill pouch:
800 → 400 mL

Dispenser:
50 → 450 mL
```

Total Home stock remains unchanged.

```text
transaction_type = TRANSFER_REFILL
quantity = 400 mL
```

## 17.6 Adjustment Example

```text
Recorded:
10 bottles

Physical count:
8 bottles

quantity_change = -2
reason = Physical stock correction
```

Quantity should not fall below zero unless explicitly configured.

---

# 18. Predictive Consumption

The app should calculate two separate predictions.

## 18.1 Active Container Duration

Answers:

> When will the currently used container need refilling or replacing?

Example:

```text
Bathroom soap dispenser:
300 mL remaining

Average usage:
25 mL/day

Estimated refill:
12 days
```

## 18.2 Overall Stock Duration

Answers:

> When will all active and reserve stock be depleted?

Example:

```text
Active dispenser:
300 mL

Reserve stock:
1,200 mL

Total:
1,500 mL

Average usage:
25 mL/day

Estimated total duration:
60 days
```

## 18.3 Prediction Outputs

```text
consumption_predictions
- id UUID
- home_id
- product_id
- average_daily_usage
- active_container_days_remaining
- total_stock_days_remaining
- estimated_refill_date
- estimated_depletion_date
- suggested_purchase_date
- confidence_score
- confidence_label
- model_version
- calculated_at
```

## 18.4 Initial Calculation Method

Machine learning is not required initially.

Use:

- Recorded `USE` transactions.
- Weighted recent average.
- Minimum history threshold.
- Outlier handling.
- Data consistency measurement.
- Rolling windows.

Suggested windows:

```text
Last 7 days
Last 30 days
Last 90 days
Lifetime
```

Recent usage should receive more weight when enough data exists.

## 18.5 Prediction Confidence

Example:

```text
Estimated depletion:
18–23 days

Confidence:
High
```

Or:

```text
Estimated depletion:
Approximately 45 days

Confidence:
Low

Reason:
Only two recorded usage events.
```

## 18.6 Excluded Events

The following must not count as consumption:

- Refill transfers.
- Moving containers.
- Packing.
- Unpacking.
- Stock corrections caused by data entry errors.
- Transfers between rooms.
- Transfers between Homes.

---

# 19. Low-Stock and Refill Alerts

The app should distinguish between:

## 19.1 Refill Alert

```text
Bathroom soap dispenser is expected to need refilling in 3 days.

Reserve stock available:
800 mL
```

## 19.2 Purchase Alert

```text
All hand-soap stock is expected to run out in 12 days.

Add to shopping list?
```

## 19.3 No Reserve Alert

```text
Dishwashing liquid is expected to run out in 4 days.

No reserve stock is recorded.
```

## 19.4 Threshold Alert

```text
Laundry pods are below the minimum level of 10 pods.
```

Users should be able to configure:

- Refill notification lead time.
- Purchase notification lead time.
- Minimum quantity.
- Notification enabled or disabled.
- Notification preview privacy.

---

# 20. Expiration Tracking

Edible and consumable items may have expiration dates.

## 20.1 Expiration States

```text
NO_EXPIRATION
VALID
EXPIRING_SOON
EXPIRED
```

Suggested defaults:

```text
Expiring soon:
Within 7 days

Upcoming:
Within 30 days
```

## 20.2 Expiration Actions

- View expiring items.
- Mark quantity as used.
- Mark quantity as disposed.
- Record expiration disposal.
- Add replacement to shopping list.
- Snooze reminder.
- Correct expiration date.

## 20.3 Multiple Batches

For MVP, different expiration dates may be represented as separate stock records.

Future model:

```text
Milk
├── Batch A — 2 units — expires 15 July
└── Batch B — 3 units — expires 22 July
```

---

# 21. Barcode and QR Support

An item may have zero, one, or multiple barcode records.

## 21.1 Supported Formats

```text
EAN-13
EAN-8
UPC-A
UPC-E
CODE-128
CODE-39
QR
DATA_MATRIX
```

## 21.2 Barcode Model

```text
item_barcodes
- id UUID
- home_id
- inventory_node_id
- barcode_value
- barcode_format
- is_primary
- created_at
```

Barcode values must be stored as text to preserve leading zeroes.

## 21.3 Scan Results

### No Match

```text
No matching item found.
```

Actions:

- Create item using scanned barcode.
- Assign barcode to existing item.
- Scan again.

### One Match

Actions:

- View.
- Use.
- Restock.
- Refill.
- Move.
- Edit.
- Pack.

### Multiple Matches

Show:

- Image.
- Item name.
- Home.
- Location.
- Quantity.
- Expiration date.

## 21.4 Internal QR Labels

Internal labels should contain only an opaque identifier.

They must not contain:

- Permanent access tokens.
- User email addresses.
- Home addresses.
- Full item data.
- Authorization credentials.

---

# 22. Images

Homes, rooms, furniture, containers, and items can have images.

## 22.1 Image Input

Primary action:

```text
Take Photo
```

Secondary action:

```text
Choose from Device
```

## 22.2 Image Editing

Before upload:

- Apply correct orientation.
- Crop.
- Reposition.
- Zoom.
- Rotate.
- Resize.
- Compress.
- Remove GPS metadata.
- Remove unnecessary EXIF metadata.

## 22.3 Suggested Aspect Ratios

```text
Item thumbnail:
1:1

Room or Home cover:
4:3 or 16:9
```

## 22.4 Suggested Sizes

```text
Thumbnail:
256 × 256

Normal item image:
1024 × 1024

Cover image:
Maximum 1600 pixels on longest edge
```

## 22.5 Image Model

```text
images
- id UUID
- home_id
- entity_type
- entity_id
- storage_path
- thumbnail_path
- mime_type
- width
- height
- file_size
- uploaded_by_user_id
- created_at
```

All images must use private storage.

---

# 23. Search and Discovery

Search should work:

- Within the current container.
- Within a room.
- Within one Home.
- Across all accessible Homes.

## 23.1 Searchable Fields

- Name.
- Description.
- Barcode.
- Brand.
- Model.
- Serial number.
- Tags.
- Room name.
- Parent container.
- Owner.
- Notes.

## 23.2 Search Result Example

```text
USB-C Charger

Bangkok Apartment
Bedroom > Desk > Bottom Drawer > Cable Organizer

Quantity:
2
```

## 23.3 Filters

```text
Home
Room
Category
Owner
Expiration status
Low stock
Container type
Has image
Has barcode
Recently added
Recently moved
Packed
Archived
```

---

# 24. Moving Items and Containers

Users may move:

- An item to another container.
- An item directly into a room.
- A container with all descendants.
- A mobile container between rooms.
- An item between Homes where authorized.

## 24.1 Move Workflow

```text
Select item
→ Move
→ Select Home
→ Select Room
→ Select Parent Container
→ Confirm
```

## 24.2 Move Validation

The system must:

- Verify source permissions.
- Verify destination permissions.
- Prevent cyclic containment.
- Validate that the destination accepts children.
- Preserve all descendants.
- Record old and new paths.
- Complete the move atomically.

---

# 25. Packing and Unpacking

Packing is a specialized movement workflow for mobile containers.

Examples:

- Suitcase.
- Backpack.
- Camera bag.
- Laptop bag.
- Tool bag.
- Diaper bag.

## 25.1 Trip Model

A Trip is an optional context for one or more mobile containers.

Example:

```text
Japan Vacation
15–22 September
```

```text
trips
- id UUID
- home_id
- created_by_user_id
- name
- destination
- start_date
- end_date
- status
- notes
- cover_image_id
- created_at
- updated_at
- archived_at
```

Trip statuses:

```text
PLANNING
PACKING
TRAVELLING
RETURNED
ARCHIVED
```

## 25.2 Trip Containers

```text
trip_containers
- id UUID
- home_id
- trip_id
- container_node_id
- added_at
- removed_at
```

A mobile container should normally belong to only one active Trip.

## 25.3 Packing List

Packing-list entries may refer to:

- A specific inventory item.
- A category.
- A text-only reminder.
- A required quantity.

```text
trip_items
- id UUID
- home_id
- trip_id
- template_item_id nullable
- inventory_node_id nullable
- label
- requested_quantity
- packed_quantity
- is_required
- status
- original_room_id nullable
- original_parent_node_id nullable
- packed_at nullable
- packed_by_user_id nullable
- unpacked_at nullable
- unpacked_by_user_id nullable
- created_at
```

Statuses:

```text
NOT_PACKED
PARTIALLY_PACKED
PACKED
SKIPPED
UNPACKED
LEFT_BEHIND
LOST
CONSUMED
DISPOSED
```

## 25.4 Packing Methods

Items can be packed through:

- Search.
- Browse inventory.
- Barcode scan.
- Previous Trip.
- Packing template.
- Manual checklist entry.
- Suggested items.

## 25.5 Packing Action

When an item is packed:

- Its parent changes to the selected mobile container.
- A `PACK` transaction is recorded.
- Its original location is stored.
- Packing-list status is updated.
- Trip activity is recorded.

## 25.6 Original Location

Example:

```text
Passport

Original location:
Bedroom > Safe Drawer

Packed location:
Carry-on > Passport Pouch
```

## 25.7 Unpacking

Users may:

- Unpack one item.
- Unpack selected items.
- Unpack all.
- Return items to original locations.
- Choose new destinations.
- Leave selected items inside the suitcase.

Example:

```text
Passport
→ Return to Safe Drawer

Dirty Clothing
→ Move to Laundry Basket

Travel Adapter
→ Leave in Carry-on
```

## 25.8 Trip Completion Check

Before completing a Trip:

```text
The following packed items have not been confirmed:

- Camera charger
- Travel umbrella
- Power bank
```

The user may mark each item:

```text
CONFIRMED
LEFT_BEHIND
LOST
CONSUMED
DISPOSED
```

---

# 26. Packing Templates

Templates support reusable checklists.

Examples:

```text
Weekend Trip
Business Trip
Beach Holiday
International Travel
Hospital Stay
Camping
```

## 26.1 Template Model

```text
packing_templates
- id UUID
- home_id
- created_by_user_id
- name
- description
- created_at
- updated_at
```

## 26.2 Template Item Model

```text
packing_template_items
- id UUID
- home_id
- template_id
- inventory_node_id nullable
- category nullable
- label
- recommended_quantity
- is_required
- notes
- sort_order
```

Templates may contain:

```text
Specific item:
MacBook Charger

Generic requirement:
Underwear × 5
```

## 26.3 Template Actions

- Create manually.
- Save from completed Trip.
- Duplicate.
- Edit quantities.
- Apply to a new Trip.
- Compare template against packed items.

---

# 27. Weight Estimation

Optional item fields:

```text
weight
weight_unit
```

Optional mobile-container fields:

```text
empty_weight
maximum_weight
airline_weight_limit
```

Estimated packed weight:

```text
container empty weight
+ sum of descendant item weights
```

Display example:

```text
Carry-on weight:
6.4 kg

Configured limit:
7.0 kg

Remaining:
0.6 kg
```

This must be labeled as an estimate unless physically measured.

---

# 28. Ownership

Each item may have an optional owner:

```text
owner_user_id
```

Examples:

- Personal laptop.
- Child's backpack.
- Shared kitchen appliance.
- Borrowed family item.

Ownership is informational and must not automatically determine access.

Access is controlled by Home membership and RLS.

---

# 29. Notifications

Homeventory will use:

- In-app notification center.
- Android push notifications through Firebase Cloud Messaging.
- No email notifications.

## 29.1 Notification Types

```text
HOME_INVITATION
INVITATION_ACCEPTED
MEMBER_REMOVED
MEMBER_ROLE_CHANGED
LOW_STOCK
REFILL_DUE
PREDICTED_DEPLETION
EXPIRING_SOON
EXPIRED
TRIP_STARTING
PACKING_INCOMPLETE
EXPECTED_UNPACKING
ITEM_NOT_CONFIRMED
STOCK_CHANGED
SECURITY_ALERT
```

## 29.2 Device Token Model

```text
device_tokens
- id UUID
- user_id
- fcm_token
- platform
- device_name
- app_version
- last_seen_at
- revoked_at
```

## 29.3 Notification Model

```text
notifications
- id UUID
- user_id
- home_id nullable
- notification_type
- title
- body
- related_entity_type nullable
- related_entity_id nullable
- read_at nullable
- created_at
```

Push delivery is not the source of truth.

Every notification should also exist inside the application.

## 29.4 Notification Preferences

```text
notification_preferences
- user_id
- low_stock_enabled
- refill_enabled
- expiration_enabled
- trip_enabled
- membership_enabled
- security_enabled
- quiet_hours_start nullable
- quiet_hours_end nullable
- preview_mode
```

Preview modes:

```text
FULL_DETAILS
HIDE_ITEM_NAMES
HIDE_ALL_CONTENT
```

## 29.5 Notification Delivery Architecture

```text
Supabase database event or scheduled job
→ Supabase Edge Function
→ Firebase Cloud Messaging
→ Android device
```

---

# 30. Activity and Audit History

Important actions should create audit records.

## 30.1 Audit Actions

```text
HOME_CREATED
HOME_UPDATED
MEMBER_INVITED
MEMBER_JOINED
MEMBER_REMOVED
MEMBER_ROLE_CHANGED
ROOM_CREATED
ROOM_UPDATED
NODE_CREATED
NODE_UPDATED
NODE_MOVED
NODE_ARCHIVED
BARCODE_ADDED
IMAGE_ADDED
QUANTITY_CHANGED
ITEM_PACKED
ITEM_UNPACKED
TRIP_CREATED
TRIP_COMPLETED
EXPORT_CREATED
```

## 30.2 Audit Model

```text
audit_logs
- id UUID
- home_id
- entity_type
- entity_id
- action
- old_values_json
- new_values_json
- performed_by_user_id
- created_at
```

Example:

```text
Aldoni moved “Travel Adapter”
from:
Office > Desk Drawer

to:
Japan Trip > Carry-on > Front Pocket
```

---

# 31. Main Mobile Screens

## 31.1 Authentication

- Continue with Google.
- Sign out.
- Session recovery.
- Account deletion.

## 31.2 Onboarding

- Welcome.
- Create first Home.
- Join Home using link, QR, or code.
- Set preferred currency.
- Set timezone.
- Choose notification preferences.

## 31.3 Home Selector

- Accessible Homes.
- Create Home.
- Join Home.
- Archived Homes.

## 31.4 Home Dashboard

- Room overview.
- Global search.
- Scan barcode.
- Low-stock items.
- Refill alerts.
- Predicted depletion.
- Expiring items.
- Active Trips.
- Recent activity.
- Notifications.

## 31.5 Room Screen

- Room image.
- Furniture.
- Top-level containers.
- Directly stored items.
- Add action.
- Search within room.

## 31.6 Container Screen

- Image.
- Breadcrumb path.
- Child containers.
- Items.
- Packing status where relevant.
- Add item.
- Move.
- Edit.
- Pack.
- Unpack.

## 31.7 Item Screen

- Image.
- Name.
- Category.
- Quantity.
- Owner.
- Location path.
- Barcode.
- Price.
- Currency.
- Purchase date.
- Expiration date.
- Use.
- Restock.
- Refill.
- Move.
- Pack.
- Transaction history.
- Audit history.

## 31.8 Scanner Screen

- Camera preview.
- Flash control.
- Scan result.
- Quick use.
- Quick restock.
- Quick refill.
- Pack scanned item.
- Add new item.

## 31.9 Prediction Dashboard

- Products needing refill.
- Products running out.
- Average consumption.
- Confidence.
- Suggested purchase dates.

## 31.10 Trip Screen

- Trip details.
- Selected containers.
- Packing progress.
- Missing items.
- Estimated weight.
- Start Trip.
- Complete Trip.
- Unpack.

## 31.11 Search Screen

- Text search.
- Barcode search.
- Filters.
- Result cards.
- Full location path.

## 31.12 Members Screen

- Owner.
- Admins.
- Editors.
- Viewers.
- Pending invitations.
- Role management.

## 31.13 Notification Center

- Unread notifications.
- Read notifications.
- Related item or Trip links.
- Notification preferences.

## 31.14 Activity Screen

- Inventory transactions.
- Item movements.
- Member changes.
- Trip activity.
- Security-sensitive events.

---

# 32. Quick Actions

A central action button may provide:

```text
Scan Barcode
Add Item
Use Item
Restock Item
Refill Container
Move Item
Start Packing
Search
```

Context-aware actions:

Inside a suitcase:

```text
Add Item
Pack Existing Item
Scan to Pack
Unpack
```

Inside an active soap dispenser:

```text
Use
Refill
View Reserve Stock
```

---

# 33. Recommended Database Tables

```text
profiles
homes
home_members
rooms
inventory_nodes
item_category_attributes
products
product_containers
item_barcodes
images
inventory_transactions
consumption_predictions
invitations
trips
trip_containers
trip_items
packing_templates
packing_template_items
notifications
notification_preferences
device_tokens
audit_logs
device_sessions
```

---

# 34. UUID Strategy

All major records should use hidden UUIDs.

Preferred:

```text
UUID v7
```

Alternative:

```text
UUID v4
```

UUIDs:

- Must not be editable.
- Must not be treated as authorization.
- Should be generated by trusted database or backend logic.
- May be used in APIs and synchronization.

---

# 35. Technical Architecture

## 35.1 Mobile Client

Recommended:

```text
Flutter
```

Reasons:

- Android-first development.
- Future iOS support.
- Camera integration.
- Barcode scanning.
- Image cropping.
- Strong local database options.
- Consistent UI.

## 35.2 Backend Platform

Recommended:

```text
Supabase
```

Components:

```text
Supabase Auth
PostgreSQL
Row Level Security
Supabase Storage
Supabase Realtime where useful
PostgreSQL Functions
Supabase Edge Functions
Scheduled jobs
```

## 35.3 Notifications

Recommended:

```text
Firebase Cloud Messaging
```

Supabase Edge Functions should send notifications using FCM.

## 35.4 State Management

Recommended options:

```text
Riverpod
Bloc
```

## 35.5 Local Storage

MVP:

```text
Minimal local cache
Secure token storage
Online-first
```

Future:

```text
Encrypted local SQLite or Drift database
Offline transaction queue
Conflict resolution
```

---

# 36. Supabase API Model

A separate traditional application server is not required for basic operations.

Basic flow:

```text
Flutter
→ Supabase Auth
→ Supabase REST API
→ PostgreSQL with RLS
```

Simple operations may use direct Supabase APIs:

- Read Homes.
- Read rooms.
- Read inventory.
- Add basic records.
- Update permitted fields.

Sensitive or multi-record operations should use trusted functions:

```text
Move container
Transfer refill stock
Accept invitation
Transfer ownership
Complete Trip
Bulk unpack
Generate export
Remove member
Send notification
```

These should use:

- PostgreSQL functions.
- Supabase Edge Functions.

A dedicated server may be added later if complexity grows.

---

# 37. Security Architecture

## 37.1 Primary Authorization Rule

Every request must verify:

```text
The authenticated user is an active member of the Home that owns the requested record.
```

Being logged in is not sufficient.

## 37.2 Row Level Security

RLS must be enabled on every exposed table.

Policies should deny access unless specifically permitted.

Policies must cover:

```text
SELECT
INSERT
UPDATE
DELETE
```

## 37.3 Direct Home Association

Every Home-scoped table should store:

```text
home_id
```

Examples:

- Rooms.
- Inventory nodes.
- Products.
- Images.
- Barcodes.
- Transactions.
- Predictions.
- Trips.
- Notifications where applicable.
- Audit logs.

## 37.4 Parent Validation

Trusted logic must verify:

```text
parent.home_id = child.home_id
room.home_id = child.home_id
destination belongs to an authorized Home
```

## 37.5 Storage Security

Images must use:

- Private buckets.
- Authorized access.
- Short-lived signed URLs.
- Protected thumbnails.
- No public object URLs.

Suggested path:

```text
homes/{home_id}/items/{item_id}/{image_id}.webp
```

The path is organizational only and must not be treated as authorization.

## 37.6 APK Secrets

Allowed in the APK:

```text
Supabase publishable key
Firebase client configuration
```

Never include:

```text
Supabase service-role key
Database password
JWT signing secret
FCM server credential
Private backend credentials
```

## 37.7 Photo Privacy

Before upload:

- Remove GPS metadata.
- Remove unnecessary EXIF data.
- Crop and resize locally.
- Avoid permanent access to the full photo library.

## 37.8 Logging

Never log:

- Access tokens.
- Invite tokens.
- Signed image URLs.
- Exact addresses.
- Receipt contents.
- Full sensitive metadata.
- Private notification payloads.

---

# 38. Security Test Matrix

Create at least:

```text
Owner A
Admin A
Editor A
Viewer A
Owner B
Removed Member A
Unauthenticated User
```

Test that:

- User A cannot access Home B.
- Viewer A cannot modify Home A.
- Removed Member A cannot access Home A.
- Anonymous users cannot access private records.
- User A cannot retrieve Home B images.
- User A cannot subscribe to Home B Realtime events.
- A Home A item cannot be assigned to a Home B parent.
- A cyclic container relationship cannot be created.
- An expired invitation cannot be accepted.
- An invitation cannot be reused.
- A service-role credential does not exist in the APK.
- Bulk unpacking cannot modify unauthorized destinations.
- FCM tokens cannot be read by other users.
- Notification records cannot be read by another user.
- A user cannot send arbitrary notifications to another Home.

---

# 39. Offline Strategy

## 39.1 MVP

Use online-first operation with limited caching.

Cache:

- Recently opened Homes.
- Basic item metadata.
- Small thumbnails where appropriate.
- Pending form state.
- Recent search results.

Avoid automatically caching:

- All full-resolution images.
- Complete Home exports.
- Every receipt.
- Full audit history.

## 39.2 Future Offline Support

- Encrypt local database.
- Protect encryption keys with Android Keystore.
- Queue offline transactions.
- Use record versions.
- Resolve conflicts.
- Clear Home data after membership revocation.
- Clear private data on logout.
- Support device revocation.

---

# 40. Export and Backup

Potential exports:

```text
CSV inventory
Spreadsheet report
PDF household inventory
Image archive
Insurance report
Trip packing list
```

Export security:

- Require recent authentication.
- Generate temporary download links.
- Record export in audit history.
- Warn that downloaded files are outside app protection.
- Avoid public export links.
- Consider encrypted archive exports later.

---

# 41. MVP Scope

## 41.1 Include in MVP

1. Google SSO.
2. User profile creation.
3. Multiple Homes.
4. In-app invitation through link, QR, or code.
5. Home roles.
6. Rooms.
7. Unified inventory nodes.
8. Nested containers.
9. Items that are also containers.
10. Item categories.
11. Quantity and units.
12. Price, currency, and purchase date.
13. Expiration dates.
14. Camera and gallery images.
15. Cropping and resizing.
16. Barcode scanning.
17. Use and restock transactions.
18. Refill transfers.
19. Search and location paths.
20. Move items and containers.
21. Basic consumption prediction.
22. Active-container refill prediction.
23. Total-stock depletion prediction.
24. Mobile containers.
25. Basic packing and unpacking.
26. Basic packing templates.
27. In-app notification center.
28. Android push notifications.
29. Audit history.
30. Private image storage.
31. RLS and cross-Home security tests.
32. Archive instead of immediate deletion.

## 41.2 Post-MVP

- Full offline synchronization.
- Advanced seasonality.
- AI image recognition.
- Receipt OCR.
- Automatic barcode product lookup.
- Multiple expiration batches.
- Warranty reminders.
- Airline baggage rule integration.
- Lending and borrowing.
- Household messaging.
- NFC labels.
- Smart-home integrations.
- Insurance valuation reports.
- Automated shopping integration.
- Depreciation estimates.
- iOS application.
- Web dashboard.

---

# 42. Development Phases

## Phase 1 — Foundation

- Create repository.
- Configure Flutter.
- Configure Supabase.
- Configure Firebase.
- Set up development and production environments.
- Implement Google SSO.
- Create profile flow.
- Add logging and error handling.
- Establish RLS policy patterns.

## Phase 2 — Home and Membership

- Create Home.
- Join Home.
- Generate invite link, QR, and code.
- Assign roles.
- Remove member.
- Home selector.
- Membership RLS tests.

## Phase 3 — Rooms and Inventory Hierarchy

- Room management.
- Inventory node model.
- Recursive containers.
- Breadcrumb paths.
- Move validation.
- Cycle prevention.
- Archive and restore.

## Phase 4 — Item Details

- Categories.
- Quantity.
- Units.
- Price and currency.
- Purchase date.
- Owner.
- Expiration.
- Category-specific fields.

## Phase 5 — Images and Barcode

- Camera capture.
- Gallery picker.
- Crop and resize.
- EXIF sanitization.
- Private uploads.
- Barcode scanner.
- Barcode lookup.
- Internal QR labels.

## Phase 6 — Inventory Transactions

- Initial stock.
- Use.
- Restock.
- Adjustment.
- Disposal.
- Refill transfer.
- Transaction history.
- Atomic functions.

## Phase 7 — Predictions

- Consumption calculation.
- Active-container forecast.
- Total-stock forecast.
- Confidence scoring.
- Refill reminders.
- Purchase-date suggestions.

## Phase 8 — Packing and Unpacking

- Mobile-container flag.
- Trip creation.
- Packing lists.
- Scan to pack.
- Original-location capture.
- Selective unpacking.
- Return to original location.
- Packing templates.
- Missing-item check.

## Phase 9 — Notifications

- In-app notification table.
- Notification center.
- FCM token registration.
- Edge Function sender.
- Quiet hours.
- Privacy previews.
- Scheduled prediction and expiration alerts.

## Phase 10 — Search and Dashboard

- Global search.
- Filters.
- Expiring products.
- Low stock.
- Predicted depletion.
- Active Trips.
- Recent activity.

## Phase 11 — Quality and Release

- Unit tests.
- Integration tests.
- Authorization tests.
- Performance tests.
- Crash reporting.
- Backup verification.
- Accessibility review.
- Internal Android testing.
- Play Store preparation.

---

# 43. Acceptance Criteria

## 43.1 Authentication

- User can sign in with Google.
- First sign-in creates a profile.
- Existing user is not duplicated.
- Logout clears private local state.
- Service-role credentials are absent from the APK.

## 43.2 Home and Permissions

- User can create multiple Homes.
- User can join using an invitation.
- Viewer cannot modify data.
- Removed member immediately loses access.
- Users cannot access another Home by changing UUIDs.

## 43.3 Hierarchy

- A room can contain furniture and items.
- A container can contain another container.
- A suitcase can be both item and container.
- There is no fixed nesting depth.
- Cyclic containment is rejected.
- Moving a container preserves descendants.

## 43.4 Images

- Camera is the primary image action.
- Gallery selection is available.
- User can crop before saving.
- GPS metadata is removed.
- Images remain private.

## 43.5 Barcode

- Barcode can be added to an item.
- Scanning finds the correct item.
- Scan can trigger use, restock, refill, or pack.
- Unknown barcode can create a new item.

## 43.6 Quantity

- Every quantity change creates a transaction.
- Refill transfer does not change total stock.
- Consumption decreases total stock.
- Quantity cannot silently become negative.

## 43.7 Predictions

- App calculates average consumption.
- Active container receives refill forecast.
- Total stock receives depletion forecast.
- Predictions display confidence.
- Refill transfers are excluded from consumption.

## 43.8 Packing

- Suitcase can be assigned to a Trip.
- Existing items can be packed.
- Original locations are retained.
- Packing progress is visible.
- Items can be selectively unpacked.
- Items can return to original locations.
- Unconfirmed items are shown before Trip completion.

## 43.9 Notifications

- Notification exists in-app even if push fails.
- User receives push for enabled events.
- Notification opens the related item or Trip.
- User can configure preview privacy.
- Another user cannot read or send notifications without authorization.

---

# 44. Product Metrics

## 44.1 Activation

- Percentage of users creating first Home.
- Percentage adding at least one room.
- Percentage adding at least five items.
- Time from login to first stored item.

## 44.2 Engagement

- Weekly active Homes.
- Searches per Home.
- Barcode scans.
- Use and restock events.
- Refill transfers.
- Active Trips.
- Packing-list completion.
- Notification interaction.

## 44.3 Value Realization

- Successful search followed by item opening.
- Items found through barcode.
- Low-stock alert actions.
- Prediction-driven restocking.
- Items returned to original location.
- Number of active shared Homes.

## 44.4 Quality

- Crash-free sessions.
- Failed image uploads.
- Failed scans.
- Prediction error.
- Authorization test failures.
- Notification delivery failures.
- Synchronization errors.

---

# 45. Initial Technical Risks

## 45.1 Authorization Complexity

Risk:

A missing RLS policy may expose another Home's data.

Mitigation:

- Deny by default.
- Shared policy helpers.
- Automated cross-Home tests.
- Security review before release.

## 45.2 Recursive Hierarchy Errors

Risk:

Circular containment or inconsistent Home and room relationships.

Mitigation:

- Trusted move function.
- Cycle detection.
- Database constraints.
- Atomic updates.

## 45.3 Prediction Misinterpretation

Risk:

Users may treat estimates as exact.

Mitigation:

- Confidence labels.
- Ranges instead of false precision.
- Explanation of limited history.
- Editable corrections.

## 45.4 Notification Overload

Risk:

Users disable all notifications.

Mitigation:

- Default only high-value alerts.
- Per-type settings.
- Quiet hours.
- Notification grouping.

## 45.5 Packing State Inconsistency

Risk:

Items are packed but original locations are lost.

Mitigation:

- Store original room and parent.
- Use transactional pack and unpack functions.
- Preserve Trip activity history.

## 45.6 Local Data Exposure

Risk:

Lost phone reveals cached inventory.

Mitigation:

- Minimal caching.
- Secure storage.
- Clear on logout.
- Future biometric lock.
- Future encrypted local database.

---

# 46. Recommended Initial Build Order

The safest practical build order is:

```text
1. Google authentication
2. Profiles
3. Homes
4. Membership and RLS
5. Rooms
6. Recursive inventory nodes
7. Search
8. Images
9. Barcode scanning
10. Quantity transactions
11. Product containers and refill
12. Predictions
13. Packing and unpacking
14. Notifications
15. Hardening and release
```

Do not build predictions, packing, or push notifications before the core Home authorization and inventory hierarchy are reliable.

---

# 47. Final Product Definition

Homeventory is a private, collaborative household inventory application that:

- Maps items to real physical locations.
- Supports unlimited nested containers.
- Treats bags and luggage as movable containers.
- Tracks quantities, prices, ownership, expiration, and barcodes.
- Records use, restock, refill, movement, packing, and unpacking.
- Predicts active-container refill timing.
- Predicts total stock depletion.
- Helps users pack and return items to their original locations.
- Supports multiple Homes and members.
- Uses Google SSO.
- Uses in-app and push notifications only.
- Protects household data using Supabase Auth, Row Level Security, private storage, and trusted transactional functions.

The product should consistently help users answer:

```text
What is it?
Where is it?
How much remains?
When will it run out?
What is it packed inside?
Where should it go back?
```
