# Understanding and exploring managed associations in CAP

This series of steps will take us on a journey exploring managed associations in the SAP Cloud Application Programming Model, where we go from a simple one-to-one managed association and ultimately end up at the stage where we've created a many-to-many relationship between two entities using a pair of to-many managed associations and a link entity to join them together.

The journey is based on [the simplest thing that could possibly work](http://c2.com/xp/DoTheSimplestThingThatCouldPossiblyWork.html): two classic entities Books and Authors, with the minimum number of elements. The data is classic too, taken from the bookshop sample and containing a handful of publications and authors. The journey starts with the two entities independent of each other, and the relationships are built up from there. Throughout, we monitor the generation of two key components - the OData metadata (in EDMX) and the SQL DDL statements that are generated for the persistence layer. We also monitor the output of the CAP server, which we run in "watch" mode. For everything we monitor, we examine any warnings or errors as they occur too, as well as make sure we understand what changes, and why.

The journey leads us on a path that ends up with a simple OData V4 service providing Books and Authors data, ultimately one that allows for books to have multiple authors, and authors to have written multiple books. But the important part of the journey is not that destination, it's the path we will take.

You can take this journey with whatever tools, IDEs, editors and command lines you feel comfortable with. 

> The instructions here will assume you're using Microsoft VS Code and that you have that set up already along with the SAP Cloud Application Programming Model development kit (Node.js) installed. It also assumes you have enough familiarity with VS Code to be able to create and edit files and run commands in the integrated terminal.

There are some simple monitoring scripts in this repo (in the [utils/](./utils) directory) to monitor for changes to files and to emit (and re-emit everytime anything changes) the EDMX (the OData metadata for the service) and the SQL DDL statements for the tables and views at the persistence layer.

Here are the steps. In most of them, there's a "Notes" section that covers what happens to the EDMX, SQL and in the CAP server output when we perform the step activities.

1. [Clone this repo and set up a new empty CAP project](#clone-this-repo-and-set-up-a-new-empty-cap-project)
1. [Start with the basic persistence layer artifacts and set up the monitoring](#start-with-the-basic-persistence-layer-artifacts-and-set-up-monitoring)
1. [Add an empty service](#add-an-empty-service)
1. [Add the Books entity but not inside the service](#add-the-books-entity-but-not-inside-the-service)
1. [Put the Books entity inside the service](#put-the-books-entity-inside-the-service)
1. [Add the Authors entity inside the service](#add-the-authors-entity-inside-the-service)
1. [Add a basic relationship with a to-one managed association, at the persistence layer](#add-a-basic-relationship-with-a-to-one-managed-association,-at-the-persistence-layer)
1. [Add the author_ID field to the Books CSV data](#add-the-author_id-field-to-the-books-csv-data)
1. [Move the current to-one managed association from the persistence layer to the service layer](#move-the-current-to-one-managed-association-from-the-persistence-layer-to-the-service-layer)
1. [Add a reverse to-many managed association from Authors to Books](#add-a-reverse-to-many-managed-association-from-authors-to-books)
1. [Fix the to-many managed association](#fix-the-to-many-managed-association)
1. [Attempt to follow the to-many managed association from author to books](#attempt-to-follow-the-to-many-managed-association-from-author-to-books)
1. [Create a link entity as the basis for a many-to-many relationship](#create-a-link-entity-as-the-basis-for-a-many-to-many-relationship)
1. [Relate each of the Books and Authors entities to the new link entity](#relate-each-of-the-books-and-authors-entities-to-the-new-link-entity)
1. [Add data to the link entity to relate books and authors](#add-data-to-the-link-entity-to-relate-books-and-authors)
1. [Add a further author and book relationship to define co-authorship](#add-a-further-author-and-book-relationship-to-define-co-authorship)

## Clone this repo and set up a new empty CAP project

We'll be starting from scratch with a new, empty CAP project, within the context of this repo (as the simple monitoring scripts you'll use are in here). 

👉 Clone this repo now, and open it in VS Code:

```shell
git clone https://github.com/qmacro/managed-associations-in-cap
code managed-associations-in-cap
```

This should start up VS Code and open within it the new `managed-associations-in-cap/` directory containing a clone of this repo.

👉 In VS Code, open a new terminal and initialise a new CAP project directly in the directory you're now in:

```shell
cds init
```

This should create various files and directories.

## Start with the basic persistence layer artifacts and set up monitoring

This is where we start the journey. Let's begin with just `Books` and `Authors` defined as entities in `db/schema.cds`, with no relationships between them. Some basic CSV data is all that we need. Note that at this point, no services are defined.

👉 Prepare the following files and content.

Create `db/schema.cds` with this content:

```cds
namespace bookshop;

entity Books {
  key ID : Integer;
  title  : String;
}
entity Authors {
  key ID : Integer;
  name   : String;
}
```

Create `srv/main.cds` with this content:

```cds
using bookshop from '../db/schema';
```

Create `db/data/bookshop-Books.csv` with this content:

```csv
ID,title
201,Wuthering Heights
207,Jane Eyre
251,The Raven
252,Eleonora
271,Catweazle
```

Create `db/data/bookshop-Authors.csv` with this content:

```csv
ID,name
101,Emily Brontë
107,Charlotte Brontë
150,Edgar Allen Poe
170,Richard Carpenter
```

Now it's time to set up the monitoring.

👉 Run each of the following in separate terminals (in VS Code you can use the ["split panes" facility in the integrated terminal](https://code.visualstudio.com/docs/terminal/basics#_groups-split-panes) for this):

* `./util/monedmx` ("EDMX")
* `./util/monsql` ("SQL")
* `cds watch` ("SERVER")

Each of these will produce output as soon as we invoke them, and will continue to monitor for changes and re-produce output as appropriate.

### Notes

EDMX: The error "There are no service definitions found at all in given model(s)" is emitted. While we have entity definitions, they are not yet exposed in any service. In fact, no service has been defined at all yet.

SQL: Basic DDL for creating TABLE artifacts only (no views) appears, and there are just the basic fields:

```sql
CREATE TABLE bookshop_Books (
  ID INTEGER NOT NULL,
  title NVARCHAR(5000),
  PRIMARY KEY(ID)
);

CREATE TABLE bookshop_Authors (
  ID INTEGER NOT NULL,
  name NVARCHAR(5000),
  PRIMARY KEY(ID)
);
```

SERVER: Data is loaded successfully from the CSV files:

```log
[cds] - connect to db > sqlite { database: ':memory:' }
 > init from db/data/bookshop-Authors.csv
 > init from db/data/bookshop-Books.csv
/> successfully deployed to sqlite in-memory db
```

But there is a message "No service definitions found in loaded models. Waiting for some to arrive...". Again, this makes sense, as we've not defined any services yet.


## Add an empty service

👉 Add `service Z;` (capital `Z`) to `srv/main.cds` so that it becomes:

```cds
using bookshop from '../db/schema';

service Z;
```

### Notes

EDMX: We now have a very basic (and empty) OData service (note the namespace is capital `Z`):

```xml
<?xml version="1.0" encoding="utf-8"?>
<edmx:Edmx Version="4.0" xmlns:edmx="http://docs.oasis-open.org/odata/ns/edmx">
  <edmx:Reference Uri="https://sap.github.io/odata-vocabularies/vocabularies/Common.xml">
    <edmx:Include Alias="Common" Namespace="com.sap.vocabularies.Common.v1"/>
  </edmx:Reference>
  <edmx:Reference Uri="https://oasis-tcs.github.io/odata-vocabularies/vocabularies/Org.OData.Core.V1.xml">
    <edmx:Include Alias="Core" Namespace="Org.OData.Core.V1"/>
  </edmx:Reference>
  <edmx:DataServices>
    <Schema Namespace="Z" xmlns="http://docs.oasis-open.org/odata/ns/edm">
      <EntityContainer Name="EntityContainer"/>
    </Schema>
  </edmx:DataServices>
</edmx:Edmx>
```

Within the main `Schema` section, the `EntityContainer` contains nothing, and there are no `EntityType`s. 

SQL: No change.

SERVER: Started. Serves capital `Z` as lower case `z`. In browser at <http://localhost:4004> service and metadata document links are shown, but there are no service endpoints. The metadata document appears as the EDMX above. The service document has no real content; the important part (the list of entitysets available, in the `value` property) is empty:

```json
{
  "@odata.context": "$metadata",
  "@odata.metadataEtag": "W/\"vRN6ru2cTrbbf2J+uTFQ1q6pPvqg8m4ot2mI8a7HpqU=\"",
  "value": []
}
```

## Add the Books entity but not inside the service

👉 Add an entity specification in `srv/main.cds`, but not inside the `service` statement. The content of this file should now look like this:

```cds
using bookshop from '../db/schema';

service Z;

entity Books as projection on bookshop.Books;
```

### Notes

EDMX: Remains unchanged, as a basic and still empty service.

SQL: A `CREATE VIEW` DDL stanza appears but note that the entity is not prefixed with any service name, i.e. `CREATE VIEW Books`, not `CREATE VIEW z_Books`:

```sql
CREATE TABLE bookshop_Books (
  ID INTEGER NOT NULL,
  title NVARCHAR(5000),
  PRIMARY KEY(ID)
);

CREATE TABLE bookshop_Authors (
  ID INTEGER NOT NULL,
  name NVARCHAR(5000),
  PRIMARY KEY(ID)
);

CREATE VIEW Books AS SELECT
  Books_0.ID,
  Books_0.title
FROM bookshop_Books AS Books_0;
```

SERVER: No sign of `Books` as a service endpoint (as it's not actually defined within the `Z` service).

## Put the Books entity inside the service

Move the entity specification in `srv/main.cds` to within the `service` statement:

**`srv/main.cds`**

```cds
using bookshop from '../db/schema';

service Z {
  entity Books as projection on bookshop.Books;
}
```

### Notes

EDMX: Now the `Books` entity appears as an `EntityType` definition within the `Schema`, and there's an `EntitySet` defined that refers to that `EntityType`.

```xml
<?xml version="1.0" encoding="utf-8"?>
<edmx:Edmx Version="4.0" xmlns:edmx="http://docs.oasis-open.org/odata/ns/edmx">
  <edmx:Reference Uri="https://sap.github.io/odata-vocabularies/vocabularies/Common.xml">
    <edmx:Include Alias="Common" Namespace="com.sap.vocabularies.Common.v1"/>
  </edmx:Reference>
  <edmx:Reference Uri="https://oasis-tcs.github.io/odata-vocabularies/vocabularies/Org.OData.Core.V1.xml">
    <edmx:Include Alias="Core" Namespace="Org.OData.Core.V1"/>
  </edmx:Reference>
  <edmx:DataServices>
    <Schema Namespace="Z" xmlns="http://docs.oasis-open.org/odata/ns/edm">
      <EntityContainer Name="EntityContainer">
        <EntitySet Name="Books" EntityType="Z.Books"/>
      </EntityContainer>
      <EntityType Name="Books">
        <Key>
          <PropertyRef Name="ID"/>
        </Key>
        <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
        <Property Name="title" Type="Edm.String"/>
      </EntityType>
    </Schema>
  </edmx:DataServices>
</edmx:Edmx>
```

SQL: The CREATE VIEW DDL statement now specifies the name to be `Z_Books`, which includes the name of the service, and not just `Books`:

```sql
CREATE TABLE bookshop_Books (
  ID INTEGER NOT NULL,
  title NVARCHAR(5000),
  PRIMARY KEY(ID)
);

CREATE TABLE bookshop_Authors (
  ID INTEGER NOT NULL,
  name NVARCHAR(5000),
  PRIMARY KEY(ID)
);

CREATE VIEW Z_Books AS SELECT
  Books_0.ID,
  Books_0.title
FROM bookshop_Books AS Books_0;
```

SERVER: There's now a `Books` service endpoint, and selecting it (to make an OData query operation on the entityset) returns the data in the CSV file - ID and title values:

```json
{
  "@odata.context": "$metadata#Books",
  "value": [
    {
      "ID": 201,
      "title": "Wuthering Heights"
    },
    {
      "ID": 207,
      "title": "Jane Eyre"
    },
    {
      "ID": 251,
      "title": "The Raven"
    },
    {
      "ID": 252,
      "title": "Eleonora"
    },
    {
      "ID": 271,
      "title": "Catweazle"
    }
  ]
}
```

## Add the Authors entity inside the service

Add another entity specification within the service, for Authors:

**`srv/main.cds`**

```cds
using bookshop from '../db/schema';

service Z {
  entity Books as projection on bookshop.Books;
  entity Authors as projection on bookshop.Authors;
}
```

### Notes

EDMX: A further `EntityType` and `EntitySet` pair appears, but note there are no navigation properties between the two entities yet:

```xml
<edmx:Edmx Version="4.0" xmlns:edmx="http://docs.oasis-open.org/odata/ns/edmx">
  <edmx:Reference Uri="https://sap.github.io/odata-vocabularies/vocabularies/Common.xml">
    <edmx:Include Alias="Common" Namespace="com.sap.vocabularies.Common.v1"/>
  </edmx:Reference>
  <edmx:Reference Uri="https://oasis-tcs.github.io/odata-vocabularies/vocabularies/Org.OData.Core.V1.xml">
    <edmx:Include Alias="Core" Namespace="Org.OData.Core.V1"/>
  </edmx:Reference>
  <edmx:DataServices>
    <Schema Namespace="Z" xmlns="http://docs.oasis-open.org/odata/ns/edm">
      <EntityContainer Name="EntityContainer">
        <EntitySet Name="Books" EntityType="Z.Books"/>
        <EntitySet Name="Authors" EntityType="Z.Authors"/>
      </EntityContainer>
      <EntityType Name="Books">
        <Key>
          <PropertyRef Name="ID"/>
        </Key>
        <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
        <Property Name="title" Type="Edm.String"/>
      </EntityType>
      <EntityType Name="Authors">
        <Key>
          <PropertyRef Name="ID"/>
        </Key>
        <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
        <Property Name="name" Type="Edm.String"/>
      </EntityType>
    </Schema>
  </edmx:DataServices>
</edmx:Edmx>
```

SQL: There's now a second CREATE VIEW DDL statement for the Authors entity in the service, also of course with the name prefixed with the service name, i.e. `Z_Authors`:

```sql
CREATE TABLE bookshop_Books (
  ID INTEGER NOT NULL,
  title NVARCHAR(5000),
  PRIMARY KEY(ID)
);

CREATE TABLE bookshop_Authors (
  ID INTEGER NOT NULL,
  name NVARCHAR(5000),
  PRIMARY KEY(ID)
);

CREATE VIEW Z_Books AS SELECT
  Books_0.ID,
  Books_0.title
FROM bookshop_Books AS Books_0;

CREATE VIEW Z_Authors AS SELECT
  Authors_0.ID,
  Authors_0.name
FROM bookshop_Authors AS Authors_0;
```

SERVER: There's also now an `Authors` service endpoint, with this data:

```json
{
  "@odata.context": "$metadata#Authors",
  "value": [
    {
      "ID": 101,
      "name": "Emily Brontë"
    },
    {
      "ID": 107,
      "name": "Charlotte Brontë"
    },
    {
      "ID": 150,
      "name": "Edgar Allen Poe"
    },
    {
      "ID": 170,
      "name": "Richard Carpenter"
    }
  ]
}
```

By the way, both the `Books` and `Authors` entitysets appear listed in the OData service document (at <http://localhost:4004/z>) now too:

```json
{
  "@odata.context": "$metadata",
  "@odata.metadataEtag": "W/\"PI1HkKOvlJRM4cAkVt1IKmiUUdFecs6vCT4ciEv/l5U=\"",
  "value": [
    {
      "name": "Books",
      "url": "Books"
    },
    {
      "name": "Authors",
      "url": "Authors"
    }
  ]
}
```

## Add a basic relationship with a to-one managed association, at the persistence layer

In `db/schema.cds`, add an `authors` element to the `Books` entity. This is a managed association, specifically a (one-) to-one association.

```cds
namespace bookshop;

entity Books {
  key ID : Integer;
  title  : String;
  author : Association to Authors;
}
entity Authors {
  key ID : Integer;
  name   : String;
}
```

### Notes

EDMX: A `NavigationPropertyBinding` element appears within the `EntitySet` for `Books`, pointing to the `EntitySet` for `Authors`, and the `Books` `EntityType` gets a new `Property` which is `author_ID` and also a `NavigationProperty` which has a `ReferentialConstraint` based on that property. Note that there's no change to the `Authors` `EntityType` definition at this point:

```xml
<?xml version="1.0" encoding="utf-8"?>
<edmx:Edmx Version="4.0" xmlns:edmx="http://docs.oasis-open.org/odata/ns/edmx">
  <edmx:Reference Uri="https://sap.github.io/odata-vocabularies/vocabularies/Common.xml">
    <edmx:Include Alias="Common" Namespace="com.sap.vocabularies.Common.v1"/>
  </edmx:Reference>
  <edmx:Reference Uri="https://oasis-tcs.github.io/odata-vocabularies/vocabularies/Org.OData.Core.V1.xml">
    <edmx:Include Alias="Core" Namespace="Org.OData.Core.V1"/>
  </edmx:Reference>
  <edmx:DataServices>
    <Schema Namespace="Z" xmlns="http://docs.oasis-open.org/odata/ns/edm">
      <EntityContainer Name="EntityContainer">
        <EntitySet Name="Books" EntityType="Z.Books">
          <NavigationPropertyBinding Path="author" Target="Authors"/>
        </EntitySet>
        <EntitySet Name="Authors" EntityType="Z.Authors"/>
      </EntityContainer>
      <EntityType Name="Books">
        <Key>
          <PropertyRef Name="ID"/>
        </Key>
        <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
        <Property Name="title" Type="Edm.String"/>
        <NavigationProperty Name="author" Type="Z.Authors">
          <ReferentialConstraint Property="author_ID" ReferencedProperty="ID"/>
        </NavigationProperty>
        <Property Name="author_ID" Type="Edm.Int32"/>
      </EntityType>
      <EntityType Name="Authors">
        <Key>
          <PropertyRef Name="ID"/>
        </Key>
        <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
        <Property Name="name" Type="Edm.String"/>
      </EntityType>
    </Schema>
  </edmx:DataServices>
</edmx:Edmx>
```

SQL: A new element `author_ID` appears in the DDL statement for creating the `bookshop_Books` table, and is referenced in the DDL statement for creating the `Z_Books` view too:

```sql
CREATE TABLE bookshop_Books (
  ID INTEGER NOT NULL,
  title NVARCHAR(5000),
  author_ID INTEGER,
  PRIMARY KEY(ID)
);

CREATE TABLE bookshop_Authors (
  ID INTEGER NOT NULL,
  name NVARCHAR(5000),
  PRIMARY KEY(ID)
);

CREATE VIEW Z_Books AS SELECT
  Books_0.ID,
  Books_0.title,
  Books_0.author_ID
FROM bookshop_Books AS Books_0;

CREATE VIEW Z_Authors AS SELECT
  Authors_0.ID,
  Authors_0.name
FROM bookshop_Authors AS Authors_0;
```

SERVER: Nothing visibly changes at the service endpoint level, but the records (entities) in the `Books` entityset now contain the new `author_ID` field, but they're all `null`:

```json
{
  "@odata.context": "$metadata#Books",
  "value": [
    {
      "ID": 201,
      "title": "Wuthering Heights",
      "author_ID": null
    },
    {
      "ID": 207,
      "title": "Jane Eyre",
      "author_ID": null
    },
    {
      "ID": 251,
      "title": "The Raven",
      "author_ID": null
    },
    {
      "ID": 252,
      "title": "Eleonora",
      "author_ID": null
    },
    {
      "ID": 271,
      "title": "Catweazle",
      "author_ID": null
    }
  ]
}
```

This suggests we need to add a new field to the `db/data/bookshop-Books.csv` file.

## Add the author_ID field to the Books CSV data

In the `utils/` dir, use `addpath` to add the dir to the PATH environment variable. Then go back to the project root and use `csvgetdata` to retrieve the Books CSV like this:

```shell
csvgetdata Books ID,title,author_ID
```

This should produce something like this:

```csv
ID,title,author_ID
201,Wuthering Heights,101
207,Jane Eyre,107
251,The Raven,150
252,Eleonora,150
271,Catweazle,170
```

Add it to the `db/data/bookshop-Books.csv` file:

```shell
csvgetdata Books ID,title,author_ID > db/data/bookshop-Books.csv
```

Now we have the values for `author_ID` in the Books data.

### Notes

EDMX: No change.

SQL: No change.

SERVER: Restarts, and now the `Books` entityset's records have values in the `author_ID` field:

```json
{
  "@odata.context": "$metadata#Books",
  "value": [
    {
      "ID": 201,
      "title": "Wuthering Heights",
      "author_ID": 101
    },
    {
      "ID": 207,
      "title": "Jane Eyre",
      "author_ID": 107
    },
    {
      "ID": 251,
      "title": "The Raven",
      "author_ID": 150
    },
    {
      "ID": 252,
      "title": "Eleonora",
      "author_ID": 150
    },
    {
      "ID": 271,
      "title": "Catweazle",
      "author_ID": 170
    }
  ]
}
```

This means we can use the `$expand` system query option from Books to follow the `author` navigation property, e.g. <http://localhost:4004/z/Books?$expand=author>, where we can see the (one-) to-one relationship where right now a book has one author and only one author:

```json
{
  "@odata.context": "$metadata#Books(author())",
  "value": [
    {
      "ID": 201,
      "title": "Wuthering Heights",
      "author_ID": 101,
      "author": {
        "ID": 101,
        "name": "Emily Brontë"
      }
    },
    {
      "ID": 207,
      "title": "Jane Eyre",
      "author_ID": 107,
      "author": {
        "ID": 107,
        "name": "Charlotte Brontë"
      }
    },
    {
      "ID": 251,
      "title": "The Raven",
      "author_ID": 150,
      "author": {
        "ID": 150,
        "name": "Edgar Allen Poe"
      }
    },
    {
      "ID": 252,
      "title": "Eleonora",
      "author_ID": 150,
      "author": {
        "ID": 150,
        "name": "Edgar Allen Poe"
      }
    },
    {
      "ID": 271,
      "title": "Catweazle",
      "author_ID": 170,
      "author": {
        "ID": 170,
        "name": "Richard Carpenter"
      }
    }
  ]
}
```

> Important: There is no change to the Authors entityset, and we cannot go the other way, i.e. we can not go from author to book. There is no navigation property available for that.

## Move the current to-one managed association from the persistence layer to the service layer

Rather than continue to work at the `db/schema.cds` level, let's move our relationship enhancements up a layer, to the service layer, and store them in an "extension" file. First, create a new, empty file `srv/extend.cds`. 

Next, remove the `author` element from the `Books` entity in `db/schema.cds` and add it as part of the following in the new `srv/extend.cds` (noting that the association target must now be specified as `bookshop.Authors` and not just `Authors`). Save the changes to both files at the same time.


```cds
using bookshop from '../db/schema';

extend bookshop.Books with {
  author: Association to bookshop.Authors;
}
```

### Notes

EDMX: No change.

SQL: No change.

SERVER: When the empty file `srv/extend.cds` is first created, the server restarts, and this new file is included when loading the model:

```log
[cds] - loaded model from 3 file(s):

  db/schema.cds
  srv/extend.cds
  srv/main.cds
```

There is no effective difference to the service, or the data available. We've just moved the definition of the (one-) to-one managed association to a separate file at the service layer, nothing more.

## Add a reverse to-many managed association from Authors to Books

So we can go from an author to the book(s) they wrote, we need to add a reverse association. Again, a managed association, but this time a to-many one.

In the `srv/extend.cds` file, add another `extend` stanza so the entire contents look like this (do not specify the `on` condition at this point):

```cds
using bookshop from '../db/schema';

extend bookshop.Books with {
  author: Association to bookshop.Authors;
}

extend bookshop.Authors with {
  books: Association to many bookshop.Books;
}
```

### Notes

EDMX: There are warnings when generating the EDMX, as follows:

```log
[WARNING] srv/extend.cds:8:3: An association can't have cardinality "to many" without an ON-condition (in entity:“bookshop.Authors”/element:“books”)
[WARNING] srv/main.cds:5:10: An association can't have cardinality "to many" without an ON-condition (in entity:“Z.Authors”/element:“books”)
```

See the [(One-)To-Many Associations](https://cap.cloud.sap/docs/guides/domain-models#one--to-many-associations) section of Capire for details. Both warnings relate to the same issue (the `Association to many bookshop.Books`), just from two different perspectives, in the `srv/extend.cds` and `srv/main.cds` files.

There have, though, been some additions to the metadata. 

In the `EntityContainer` area, the `Authors` `EntitySet` now has a `NavigationPropertyBinding` pointing to the `Books` `EntitySet`. So instead of just:

```xml
<EntityContainer Name="EntityContainer">
  <EntitySet Name="Books" EntityType="Z.Books">
    <NavigationPropertyBinding Path="author" Target="Authors"/>
  </EntitySet>
  <EntitySet Name="Authors" EntityType="Z.Authors"/>
</EntityContainer>
```

we now see:

```xml
<EntityContainer Name="EntityContainer">
  <EntitySet Name="Books" EntityType="Z.Books">
    <NavigationPropertyBinding Path="author" Target="Authors"/>
  </EntitySet>
  <EntitySet Name="Authors" EntityType="Z.Authors">
    <NavigationPropertyBinding Path="books" Target="Books"/>
  </EntitySet>
</EntityContainer>
```

In the list of `EntityType`s, there are some additions in the the `Authors` `EntityType`:

```xml
<EntityType Name="Authors">
  <Key>
    <PropertyRef Name="ID"/>
  </Key>
  <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
  <Property Name="name" Type="Edm.String"/>
  <NavigationProperty Name="books" Type="Collection(Z.Books)"/>
  <Property Name="books_ID" Type="Edm.Int32"/>
</EntityType>
```

First, the `Authors` `EntityType` now has a `NavigationProperty`, about which there are two things to notice:

* The type is specified as `Collection(Z.Books)`, because it's for this to-many association
* While there is a `ReferentialConstraint` defined for the already-existing to-one association from earlier (for `Books.author`):
    ```xml
    <NavigationProperty Name="author" Type="Z.Authors">
      <ReferentialConstraint Property="author_ID" ReferencedProperty="ID"/>
    </NavigationProperty>
    ```
  there is no `ReferentialConstraint` for this new to-many association.

Second, there is also an additional `Property` for the `books_ID` element that was created as a result of this new managed to-many association.

SQL: The same warnings appear as did for the EDMX (and for the same reason, of course):

```log
[WARNING] srv/extend.cds:8:3: An association can't have cardinality "to many" without an ON-condition (in entity:“bookshop.Authors”/element:“books”)
[WARNING] srv/main.cds:5:10: An association can't have cardinality "to many" without an ON-condition (in entity:“Z.Authors”/element:“books”)
```

The resulting SQL reflects the addition of this to-many managed association, via the new `books_ID` element in the DDL for the `bookshop_Authors` table, and the new `Authors_0.books_ID` element in the DDL for the `Z_Authors` view:

```sql
CREATE TABLE bookshop_Books (
  ID INTEGER NOT NULL,
  title NVARCHAR(5000),
  author_ID INTEGER,
  PRIMARY KEY(ID)
);

CREATE TABLE bookshop_Authors (
  ID INTEGER NOT NULL,
  name NVARCHAR(5000),
  books_ID INTEGER,
  PRIMARY KEY(ID)
);

CREATE VIEW Z_Books AS SELECT
  Books_0.ID,
  Books_0.title,
  Books_0.author_ID
FROM bookshop_Books AS Books_0;

CREATE VIEW Z_Authors AS SELECT
  Authors_0.ID,
  Authors_0.name,
  Authors_0.books_ID
FROM bookshop_Authors AS Authors_0;
```

SERVER: The `Authors` entityset records now show that new `books_ID` element, and the value for each one is `null`:

```json
{
  "@odata.context": "$metadata#Authors",
  "value": [
    {
      "ID": 101,
      "name": "Emily Brontë",
      "books_ID": null
    },
    {
      "ID": 107,
      "name": "Charlotte Brontë",
      "books_ID": null
    },
    {
      "ID": 150,
      "name": "Edgar Allen Poe",
      "books_ID": null
    },
    {
      "ID": 170,
      "name": "Richard Carpenter",
      "books_ID": null
    }
  ]
}
```

> Important: As it stands, this to-many managed association isn't quite right. Given that there's only a single scalar value that can be specified for `books_ID`, how on earth could we relate an author to more than one book?

## Fix the to-many managed association

The to-many managed association won't work for what we want, we can't relate an author to more than one book. The association is only half-baked at this point anyway, as we can see from the warnings that are emitted. Let's address that now, by adding the `on` condition. After adding it, the contents of the `srv/extend.cds` should look like this:

```cds
using bookshop from '../db/schema';

extend bookshop.Books with {
  author: Association to bookshop.Authors;
}

extend bookshop.Authors with {
  books: Association to many bookshop.Books on books.author = $self;
}
```

### Notes

EDMX: There are no further changes to the details of the `Authors` `EntitySet`, it is as it was before we added the `on` condition:

```xml
<EntityContainer Name="EntityContainer">
  <EntitySet Name="Books" EntityType="Z.Books">
    <NavigationPropertyBinding Path="author" Target="Authors"/>
  </EntitySet>
  <EntitySet Name="Authors" EntityType="Z.Authors">
    <NavigationPropertyBinding Path="books" Target="Books"/>
  </EntitySet>
</EntityContainer>
```

However, both the `Books` and `Authors` `EntityType`s have changed. 

The `Books` `EntityType` (the target of this (one-) to-many managed association) now has, in its existing `NavigationProperty`, a new attribute `Partner="books"`:


```xml
<EntityType Name="Books">
  <Key>
    <PropertyRef Name="ID"/>
  </Key>
  <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
  <Property Name="title" Type="Edm.String"/>
  <NavigationProperty Name="author" Type="Z.Authors" Partner="books">
    <ReferentialConstraint Property="author_ID" ReferencedProperty="ID"/>
  </NavigationProperty>
  <Property Name="author_ID" Type="Edm.Int32"/>
</EntityType>
```

The `Authors` `EntityType` also has a similar but opposite attribute in its existing `NavigationProperty`, i.e. `Partner="author"`:

```xml
<EntityType Name="Authors">
  <Key>
    <PropertyRef Name="ID"/>
  </Key>
  <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
  <Property Name="name" Type="Edm.String"/>
  <NavigationProperty Name="books" Type="Collection(Z.Books)" Partner="author"/>
</EntityType>
```

But more crucially, this property:

```xml
<Property Name="books_ID" Type="Edm.Int32"/>
```

has now disappeared again. This makes sense, in that it absolutely didn't make sense to have a `book_ID` property to link an author to potential multiple books. 

SQL: Correspondingly, the `book_ID` element has now disappeared again from both the table and the view DDL statements:

```sql
CREATE TABLE bookshop_Books (
  ID INTEGER NOT NULL,
  title NVARCHAR(5000),
  author_ID INTEGER,
  PRIMARY KEY(ID)
);

CREATE TABLE bookshop_Authors (
  ID INTEGER NOT NULL,
  name NVARCHAR(5000),
  PRIMARY KEY(ID)
);

CREATE VIEW Z_Books AS SELECT
  Books_0.ID,
  Books_0.title,
  Books_0.author_ID
FROM bookshop_Books AS Books_0;

CREATE VIEW Z_Authors AS SELECT
  Authors_0.ID,
  Authors_0.name
FROM bookshop_Authors AS Authors_0;
```

SERVER: No change.

## Attempt to follow the to-many managed association from author to book(s)

The managed association is set up, and appears correct. What about the data? Do we have enough information to go from an author to the one or more books they wrote?

The data we have at the persistence layer, in the form of the CSV files, looks like this, for `db/data/bookshop-Books.csv`:

```csv
ID,title,author_ID
201,Wuthering Heights,101
207,Jane Eyre,107
251,The Raven,150
252,Eleonora,150
271,Catweazle,170
```

and for `db/data/bookshop-Authors.csv`:

```csv
ID,name
101,Emily Brontë
107,Charlotte Brontë
150,Edgar Allen Poe
170,Richard Carpenter
```

Note that there is no field in this authors data that explicitly points to book identifier(s). The relationships are maintained in the books data, simply in the `author_ID` field.

First, make a simple OData query operation to retrieve the Authors entityset <http://localhost:4004/z/Authors>:

```json
{
  "@odata.context": "$metadata#Authors",
  "value": [
    {
      "ID": 101,
      "name": "Emily Brontë"
    },
    {
      "ID": 107,
      "name": "Charlotte Brontë"
    },
    {
      "ID": 150,
      "name": "Edgar Allen Poe"
    },
    {
      "ID": 170,
      "name": "Richard Carpenter"
    }
  ]
}
```

This reflects exactly the fields and data within, in the CSV file. No `book_ID` any more.

Now use the `$expand` system query option to follow the navigation property (this one `<NavigationProperty Name="books" Type="Collection(Z.Books)" Partner="author"/>`) <http://localhost:4004/z/Authors?$expand=books> - this should return something like this:

```json
{
  "@odata.context": "$metadata#Authors(books())",
  "value": [
    {
      "ID": 101,
      "name": "Emily Brontë",
      "books": [
        {
          "ID": 201,
          "title": "Wuthering Heights",
          "author_ID": 101
        }
      ]
    },
    {
      "ID": 107,
      "name": "Charlotte Brontë",
      "books": [
        {
          "ID": 207,
          "title": "Jane Eyre",
          "author_ID": 107
        }
      ]
    },
    {
      "ID": 150,
      "name": "Edgar Allen Poe",
      "books": [
        {
          "ID": 251,
          "title": "The Raven",
          "author_ID": 150
        },
        {
          "ID": 252,
          "title": "Eleonora",
          "author_ID": 150
        }
      ]
    },
    {
      "ID": 170,
      "name": "Richard Carpenter",
      "books": [
        {
          "ID": 271,
          "title": "Catweazle",
          "author_ID": 170
        }
      ]
    }
  ]
}
```

Of course, this is a fully functional navigation property so we can build OData query operations like these (somewhat contrived) examples:

* Authors, listing their books that have titles that contain "the" [http://localhost:4004/z/Authors?$expand=books($filter=contains(title,'the'))](http://localhost:4004/z/Authors?$expand=books($filter=contains(title,%27the%27)))
* Authors, listing their books but just the title information [http://localhost:4004/z/Authors?$expand=books($select=title)](http://localhost:4004/z/Authors?$expand=books($select=title)
* Authors that have written more than one book [http://localhost:4004/z/Authors?$filter=books/$count gt 1](http://localhost:4004/z/Authors?$filter=books/$count%20gt%201)
* Authors that have written more than one book, listing what they wrote [http://localhost:4004/z/Authors?$filter=books/$count gt 1&$expand=books($select=title)](http://localhost:4004/z/Authors?$filter=books/$count%20gt%201&$expand=books($select=title))
* And just a final and ridiculous example of multiple nested expands [http://localhost:4004/z/Authors?$filter=books/$count gt 1&$expand=books($expand=author($expand=books))](http://localhost:4004/z/Authors?$filter=books/$count%20gt%201&$expand=books($expand=author($expand=books))) which returns this:
  ```json
  {
    "@odata.context": "$metadata#Authors(books(author(books())))",
    "value": [
      {
        "ID": 150,
        "name": "Edgar Allen Poe",
        "books": [
          {
            "ID": 251,
            "title": "The Raven",
            "author_ID": 150,
            "author": {
              "ID": 150,
              "name": "Edgar Allen Poe",
              "books": [
                {
                  "ID": 251,
                  "title": "The Raven",
                  "author_ID": 150
                },
                {
                  "ID": 252,
                  "title": "Eleonora",
                  "author_ID": 150
                }
              ]
            }
          },
          {
            "ID": 252,
            "title": "Eleonora",
            "author_ID": 150,
            "author": {
              "ID": 150,
              "name": "Edgar Allen Poe",
              "books": [
                {
                  "ID": 251,
                  "title": "The Raven",
                  "author_ID": 150
                },
                {
                  "ID": 252,
                  "title": "Eleonora",
                  "author_ID": 150
                }
              ]
            }
          }
        ]
      }
    ]
  }
  ```

> See [Back to basics: OData - the Open Data Protocol - Part 4 - All things $filter](https://www.youtube.com/watch?v=R9JyaPYtWKs&list=PL6RpkC85SLQDYLiN1BobWXvvnhaGErkwj&index=5) and the accompanying [All things $filter](https://github.com/SAP-samples/odata-basics-handsonsapdev/blob/main/filter.md) document for more details.

So everything seems to work as intended, a (one-) to-one managed association from `Books` to `Authors`, and a (one-) to-many managed association from `Authors` to `Books`, effectively providing a reverse route.

## Create a link entity as the basis for a many-to-many relationship

While CDS doesn't currently directly support many-to-many relationships (see [Many-to-Many Association](https://cap.cloud.sap/docs/guides/domain-models#many-to-many-associations)), they can be achieved by using a so-called "link entity" to bind two (one) to-many managed associations together.

In the `srv/extend.cds` file, add a new entity `Books_Authors` so that the contents look as follows:

```cds
using bookshop from '../db/schema';

extend bookshop.Books with {
  author: Association to bookshop.Authors;
}

extend bookshop.Authors with {
  books: Association to many bookshop.Books on books.author = $self;
}

entity Books_Authors {
  book: Association to bookshop.Books;
  author: Association to bookshop.Authors;
}
```

### Notes

EDMX: No change (because while there's a new entity, it's not exposed in the service definition (in `srv/main.cds`).

SQL: A new table definition is added for this link entity, the DDL looks like this:

```sql
CREATE TABLE Books_Authors (
  book_ID INTEGER,
  author_ID INTEGER
);
```

SERVER: No change.

## Relate each of the Books and Authors entities to the new link entity

Think of the link entity as a central "plumbing" facility, that just has a list of (in this case) pairs of numeric author and book IDs, linking authors and books. Then, from either side, we need to links the Books entity and Authors entity to that central plumbing facility, i.e. the link entity.

Right now, the relationships defined in `srv/extend.cds`, going from `bookshop.Books` and going from `bookshop.Authors`, go to each other, i.e. these are the two managed association definitions (see just earlier for the entire contents):

* The current (one-) to-one managed association:
  ```cds
  extend bookshop.Books with {
    author: Association to bookshop.Authors;
  }
  ```

* And the current (one-) to-many managed association:
  ```cds
  extend bookshop.Authors with {
    books: Association to many bookshop.Books on books.author = $self;
  }
  ```

Now we need to change those to point to the corresponding elements in the new link entity `Books_Authors`. 

Modify the `srv/extend.cds` so the entire contents look like this (note that each of the element names are plural now):

```cds
using bookshop from '../db/schema';

extend bookshop.Books with {
  authors: Association to many Books_Authors on authors.book = $self;
}

extend bookshop.Authors with {
  books: Association to many Books_Authors on books.author = $self;
}

entity Books_Authors {
  book: Association to bookshop.Books;
  author: Association to bookshop.Authors;
}
```

> It's at this point worth mentioning the way I remember how the `on` conditions are specified, as the examples here are clean and clear to use in an explanation. In the first example here (`authors: Association to many Books_Authors on authors.book = $self`) the left hand side of the condition, `authors.book` is constructed from the name of the element we're defining (`authors`), and the name of the element in the target entity (i.e. `book`), that is `authors.book`. Similarly for `books.author` in the second example.

This modification causes quite a bit of a change, including warnings!

### Notes

EDMX: A warning is emitted thus:

```log
[WARNING] srv/main.cds:4:10: No OData navigation property generated, target “Books_Authors” is outside of service “Z” (in entity:“Z.Books”/element:“authors”)
[WARNING] srv/main.cds:5:10: No OData navigation property generated, target “Books_Authors” is outside of service “Z” (in entity:“Z.Authors”/element:“books”)
```

The message is clear, although it's best to read this one from back to front. In other words, because `Books_Authors` is not included in the `Z` service definition, which is true (we haven't added anything inside the `service Z { ... }` to include it yet) ... a navigation property binding at the OData level cannot be generated (because there isn't anywhere for it to point - there is no target entity type for this link entity, and consequently no entityset either as a target for the navigation).

As a result of this omission, all relationships (in the form of navigation properties) have disappeared, and we're back to almost where we started (with just simple properties for the book IDs and titles, and the author IDs and names):

```xml
<?xml version="1.0" encoding="utf-8"?>
<edmx:Edmx Version="4.0" xmlns:edmx="http://docs.oasis-open.org/odata/ns/edmx">
  <edmx:Reference Uri="https://sap.github.io/odata-vocabularies/vocabularies/Common.xml">
    <edmx:Include Alias="Common" Namespace="com.sap.vocabularies.Common.v1"/>
  </edmx:Reference>
  <edmx:Reference Uri="https://oasis-tcs.github.io/odata-vocabularies/vocabularies/Org.OData.Core.V1.xml">
    <edmx:Include Alias="Core" Namespace="Org.OData.Core.V1"/>
  </edmx:Reference>
  <edmx:DataServices>
    <Schema Namespace="Z" xmlns="http://docs.oasis-open.org/odata/ns/edm">
      <EntityContainer Name="EntityContainer">
        <EntitySet Name="Books" EntityType="Z.Books"/>
        <EntitySet Name="Authors" EntityType="Z.Authors"/>
      </EntityContainer>
      <EntityType Name="Books">
        <Key>
          <PropertyRef Name="ID"/>
        </Key>
        <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
        <Property Name="title" Type="Edm.String"/>
      </EntityType>
      <EntityType Name="Authors">
        <Key>
          <PropertyRef Name="ID"/>
        </Key>
        <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
        <Property Name="name" Type="Edm.String"/>
      </EntityType>
    </Schema>
  </edmx:DataServices>
</edmx:Edmx>
```

This is of course just a temporary state, we're not done yet.

SQL: There have been corresponding changes at the SQL level too, albeit a little less extreme but with just as much impact. The `author_ID` field has been removed. This makes sense, as it was only introduced because of the (one-) to-one managed association from `Books` to `Authors`, and this has now been replaced. This is what the SQL looks like at this point:

```sql
CREATE TABLE Books_Authors (
  book_ID INTEGER,
  author_ID INTEGER
);

CREATE TABLE bookshop_Books (
  ID INTEGER NOT NULL,
  title NVARCHAR(5000),
  PRIMARY KEY(ID)
);

CREATE TABLE bookshop_Authors (
  ID INTEGER NOT NULL,
  name NVARCHAR(5000),
  PRIMARY KEY(ID)
);

CREATE VIEW Z_Books AS SELECT
  Books_0.ID,
  Books_0.title
FROM bookshop_Books AS Books_0;

CREATE VIEW Z_Authors AS SELECT
  Authors_0.ID,
  Authors_0.name
FROM bookshop_Authors AS Authors_0;
```

The only place where we see any sort of "generated" `_ID` fields (as a result of managed associations) is in the DDL definition for the link entity table `Books_Authors`. But that right now is pretty much an island doing nothing and connected to nothing.

SERVER: We see an error emitted:

```log
[cds] - connect to db > sqlite { database: ':memory:' }
 > init from db/data/bookshop-Authors.csv
 > init from db/data/bookshop-Books.csv
[ERROR] SQLITE_ERROR: table bookshop_Books has no column named author_ID in: 
INSERT INTO bookshop_Books ( ID, title, author_ID ) VALUES ( ?, ?, ? )
```

This makes sense, as there is no longer any `author_ID`. So let's get rid of that from the CSV file `db/data/bookshop-Books.csv`. And that's not wasted effort that we'll have to shortly undo, because when we do want to rebuild that relationship (between books and authors), we won't be doing it in the `db/data/bookshop-Books.csv` file, we'll be doing it in the CSV file that corresponds to the link entity.

Use the utility `csvdelfield` in the `utils/` directory to do this. First, try it out, specifying the name of the CSV file, like this:

```shell
csvdelfield db/data/bookshop-Books.csv
```
It should show a list of current fields, like this:

```log
ID,title,author_ID
```

Now re-run it, this time specifying the `author_ID` field that we want to delete (warning: this will actually modify the CSV file contents directly, as well as displaying the new content:

```shell
csvdelfield db/data/bookshop-Books.csv author_ID
ID,title
201,Wuthering Heights
207,Jane Eyre
251,The Raven
252,Eleonora
271,Catweazle
```

Because of this change to the CSV file, the CAP server will restart (as we're still running `cds watch`) and reload the CSV files, and this time there is no error:

```log
[cds] - connect to db > sqlite { database: ':memory:' }
 > init from db/data/bookshop-Authors.csv
 > init from db/data/bookshop-Books.csv
/> successfully deployed to sqlite in-memory db
```

## Add data to the link entity to relate books and authors

The `Books_Authors` link entity is represented at the persistence layer with a simple table which we know is defined like this:

```sql
CREATE TABLE Books_Authors (
  book_ID INTEGER,
  author_ID INTEGER
);
```

So we can now relate books and authors by defining pairs of IDs in a new file `db/data/Books_Authors.csv`. The name follows the usual convention, even though it looks a little different to the names of the other CSV files here; it is the namespace and entity name, but as there's no namespace that contextualises the entity here, there's no `<namespace>-` prefix part in the filename. 

Let's start by restoring the relationships we had before, where Charlotte Brontë wrote Wuthering Heights, Emily Brontë wrote Jane Eyre, Richard Carpenter wrote Catweazle, and Edgar Allen Poe, wrote Eleonora and also The Raven (a poem, as it happens).

In `db/data/Books_Authors.csv`, add the following:

```csv
book_ID,author_ID
201,101
207,107
251,150
252,150
271,170
```

### Notes

EDMX: No change.

SQL: No change.

SERVER: The server restarts, and shows that data is now also being loaded from this new CSV file:

```log
[cds] - connect to db > sqlite { database: ':memory:' }
 > init from db/data/Books_Authors.csv
 > init from db/data/bookshop-Authors.csv
 > init from db/data/bookshop-Books.csv
/> successfully deployed to sqlite in-memory db
```

We can now traverse one level of relationships, to find the books that authors wrote, such as with [http://localhost:4004/z/Authors?$expand=books](http://localhost:4004/z/Authors?$expand=books), which produces this:

```json
{
  "@odata.context": "$metadata#Authors(books())",
  "value": [
    {
      "ID": 101,
      "name": "Emily Brontë",
      "books": [
        {
          "book_ID": 201,
          "author_ID": 101
        }
      ]
    },
    {
      "ID": 107,
      "name": "Charlotte Brontë",
      "books": [
        {
          "book_ID": 207,
          "author_ID": 107
        }
      ]
    },
    {
      "ID": 150,
      "name": "Edgar Allen Poe",
      "books": [
        {
          "book_ID": 251,
          "author_ID": 150
        },
        {
          "book_ID": 252,
          "author_ID": 150
        }
      ]
    },
    {
      "ID": 170,
      "name": "Richard Carpenter",
      "books": [
        {
          "book_ID": 271,
          "author_ID": 170
        }
      ]
    }
  ]
}
```

Note that there is no author name information shown, we just get author ID information. That's because the author name is one step further on. Right now, we can see this query and result as jumping half way across a stream to a stone in the middle, which represents the link entity. To get to the other side, we need to take a second jump.

We can use the power of OData V4 to make the second jump so that we effectively cover both steps in one go, from `Books` to `Books_Authors` to `Authors`, like this: [http://localhost:4004/z/Authors?$expand=books($expand=book)](http://localhost:4004/z/Books?$expand=authors($expand=author)), which will emit:

```json
{
  "@odata.context": "$metadata#Books(authors(author()))",
  "value": [
    {
      "ID": 201,
      "title": "Wuthering Heights",
      "authors": [
        {
          "book_ID": 201,
          "author_ID": 101,
          "author": {
            "ID": 101,
            "name": "Emily Brontë"
          }
        }
      ]
    },
    {
      "ID": 207,
      "title": "Jane Eyre",
      "authors": [
        {
          "book_ID": 207,
          "author_ID": 107,
          "author": {
            "ID": 107,
            "name": "Charlotte Brontë"
          }
        }
      ]
    },
    {
      "ID": 251,
      "title": "The Raven",
      "authors": [
        {
          "book_ID": 251,
          "author_ID": 150,
          "author": {
            "ID": 150,
            "name": "Edgar Allen Poe"
          }
        }
      ]
    },
    {
      "ID": 252,
      "title": "Eleonora",
      "authors": [
        {
          "book_ID": 252,
          "author_ID": 150,
          "author": {
            "ID": 150,
            "name": "Edgar Allen Poe"
          }
        }
      ]
    },
    {
      "ID": 271,
      "title": "Catweazle",
      "authors": [
        {
          "book_ID": 271,
          "author_ID": 170,
          "author": {
            "ID": 170,
            "name": "Richard Carpenter"
          }
        }
      ]
    }
  ]
}
```

## Add a further author and book relationship to define co-authorship

As a final test, let's create a fictional collaboration between Ellis Bell and Emily Brontë. Ellis Bell was the pseudonym under which Emily Brontë wrote Wuthering Heights, so it sort of makes sense. Or maybe it doesn't. Anyway. 

Add a new record to the end of `db/data/bookshop-Authors.csv` to represent Ellis Bell, so it looks like this:

```csv
ID,name
101,Emily Brontë
107,Charlotte Brontë
150,Edgar Allen Poe
170,Richard Carpenter
102,Ellis Bell
```

Also add a new record to the end of `db/data/Books_Authors.csv` to link book Wuthering Heights (ID 201) with author Ellis Bell (102), so it looks like this:

```csv
book_ID,author_ID
201,101
207,107
251,150
252,150
271,170
201,102
```

Now check that both Emily Brontë and Ellis Bell appear as authors, with [http://localhost:4004/z/Authors?$search=Ellis OR Emily](http://localhost:4004/z/Authors?$search=Ellis%20OR%20Emily) for example:

```json
{
  "@odata.context": "$metadata#Authors",
  "value": [
    {
      "ID": 101,
      "name": "Emily Brontë"
    },
    {
      "ID": 102,
      "name": "Ellis Bell"
    }
  ]
}
```

And now check that Wuthering Heights is now recorded as being co-written by both authors, with [http://localhost:4004/z/Books?$filter=title%20eq%20%27Wuthering%20Heights%27&$expand=authors($expand=author)](http://localhost:4004/z/Books?$filter=title%20eq%20%27Wuthering%20Heights%27&$expand=authors($expand=author)):

```json
{
  "@odata.context": "$metadata#Books(authors(author()))",
  "value": [
    {
      "ID": 201,
      "title": "Wuthering Heights",
      "authors": [
        {
          "book_ID": 201,
          "author_ID": 101,
          "author": {
            "ID": 101,
            "name": "Emily Brontë"
          }
        },
        {
          "book_ID": 201,
          "author_ID": 102,
          "author": {
            "ID": 102,
            "name": "Ellis Bell"
          }
        }
      ]
    }
  ]
}
```

Excellent!
