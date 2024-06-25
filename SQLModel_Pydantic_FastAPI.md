### Python FastAPI's SQLModel with pydantic schemas

Python's FastAPI with SQLModel and Pydantic schemas to handle various operations:

1. **Setting up the environment:**
    - First, make sure you have the required packages installed:
      ```sh
      pip install fastapi uvicorn sqlmodel sqlite
      ```

2. **Example Application:**

   - **Database Models with SQLModel:**

   ```python
   from sqlmodel import Field, SQLModel, create_engine, Session, select
   from typing import Optional

   class ItemBase(SQLModel):
       name: str
       description: Optional[str] = None
       price: float

   class Item(ItemBase, table=True):
       id: Optional[int] = Field(default=None, primary_key=True)

   sqlite_file_name = "database.db"
   sqlite_url = f"sqlite:///{sqlite_file_name}"

   engine = create_engine(sqlite_url, echo=True)

   def create_db_and_tables():
       SQLModel.metadata.create_all(engine)
   ```

   - **Pydantic Schema:**

   ```python
   from pydantic import BaseModel
   
   class ItemCreateRequest(BaseModel):
       name: str
       description: Optional[str] = None
       price: float
   ```

   - **FastAPI Setup:**

   ```python
   from fastapi import FastAPI, HTTPException
   from sqlmodel import Session

   app = FastAPI()

   create_db_and_tables()

   @app.post("/items/", response_model=Item)
   def create_item(item: ItemCreateRequest):
       with Session(engine) as session:
           db_item = Item(**item.dict())
           session.add(db_item)
           session.commit()
           session.refresh(db_item)
           return db_item

   @app.put("/items/{item_id}", response_model=Item)
   def update_item(item_id: int, item_update: ItemCreateRequest):
       with Session(engine) as session:
           statement = select(Item).where(Item.id == item_id)
           result = session.exec(statement)
           db_item = result.first()

           if not db_item:
               raise HTTPException(status_code=404, detail="Item not found")
           
           for key, value in item_update.dict().items():
               setattr(db_item, key, value)
           
           session.add(db_item)
           session.commit()
           session.refresh(db_item)
           return db_item

   @app.get("/items/{item_id}")
   def read_item(item_id: int):
       with Session(engine) as session:
           statement = select(Item).where(Item.id == item_id)
           result = session.exec(statement)
           db_item = result.first()

           if db_item is None:
               raise HTTPException(status_code=404, detail="Item not found")
           
           return db_item
   ```

   - **Example Update Function with Added Computed Values:**

   ```python
   from fastapi import Request
   
   @app.post("/compute_price/", response_model=Item)
   async def compute_price(request: Request):
       data = await request.json()
       item_id = data.get('id')
       discount = data.get('discount', 0)

       with Session(engine) as session:
           statement = select(Item).where(Item.id == item_id)
           result = session.exec(statement)
           db_item = result.first()

           if not db_item:
               raise HTTPException(status_code=404, detail="Item not found")
           
           # Compute new price
           new_price = db_item.price * (1 - discount)
           response_item = db_item.dict()
           response_item['computed_price'] = new_price
           
           return response_item
   ```

   
   Here's a walkthrough of what the code does:
   
   1. `ItemBase` and `Item`: These models represent the schema of the database, with `ItemBase` acting as a base class and `Item` having an additional `id` which becomes a primary key in the database. `SQLModel` is used to easily interface with SQLAlchemy.

   2. `ItemCreateRequest`: A Pydantic schema used to validate incoming request data for creating or updating items.

   3. The `FastAPI` instance `app` is where all the API routes are defined.

   4. `create_item`: This endpoint takes a `POST` request with item details, uses them to create a new `Item` in the database and responds with the created item.

   5. `update_item`: This endpoint takes a `PUT` request with an `id` parameter and item details, finds the existing item in the database and updates its details. 

   6. `read_item`: A `GET` endpoint that retrieves the details of a specific item based on its `id`.

   7. `compute_price`: A `POST` endpoint where you send JSON data including an item's `id` and a `discount`. It retrieves the item, calculates the discounted price, and responds with both the original and the discounted price.

   - **Running the App:**

     Save the code into a file named `main.py` and then run:

     ```sh
     uvicorn main:app --reload
     ```

   This will start the FastAPI server, and you can interact with the API at `http://127.0.0.1:8000` through endpoints such as `/items/` for creating items, `/items/{item_id}` for updating and fetching items, and `/compute_price/` for calculating the discounted price.

