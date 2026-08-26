# Bangkok demo studio

Furnished 24 m² Bangkok studio used for product demos.

## Load it

Sign in. **Your homes** creates **Bangkok studio** if you do not already have one (you are the owner). You can also tap **Demo studio**. That home has three rooms, 68 inventory rows from the spreadsheet, nested furniture, and the apartment photos.

SQL in the dashboard cannot create this home: the rooms, items, and photos are installed by the Flutter client. A `P0002 query returned no rows` error means the home is not in Postgres yet.

## Source files

| File | Role |
| --- | --- |
| [`Homeventory_Demo_Studio_Inventory.xlsx`](Homeventory_Demo_Studio_Inventory.xlsx) | Item list, prices (THB), locations |
| [`../../mobile/assets/demo_studio/catalog.json`](../../mobile/assets/demo_studio/catalog.json) | Nested tree the app installs |
| [`../../mobile/assets/demo_studio/*.jpg`](../../mobile/assets/demo_studio/) | Home, room, and furniture photos |

Totals: 68 inventory entries, quantity 143, listed value ฿213,925.
