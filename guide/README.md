# Understanding and exploring managed associations in CAP

This series of steps will take us on a journey exploring managed associations in the SAP Cloud Application Programming Model, where we go from a simple one-to-one managed association and ultimately end up at the stage where we've created a many-to-many relationship between two entities using a pair of (one-) to-many managed associations and a link entity to join them together.

The journey is based on [the simplest thing that could possibly work](http://c2.com/xp/DoTheSimplestThingThatCouldPossiblyWork.html): two classic entities books and authors, with the minimum number of elements. The data is classic too, taken from the bookshop sample in the [SAP-samples/cloud-cap-samples](https://github.com/SAP-samples/cloud-cap-samples/) repo, and contains just a handful of publications and authors. The journey starts with the two entities independent of each other, and the relationships are built up from there. 

Throughout, we monitor the generation of two key components - the OData metadata (in EDMX) and the SQL DDL statements that are generated for the persistence layer. We also monitor the output of the CAP server, which we run in "watch" mode. For everything we monitor, we examine any warnings or errors as they occur too, as well as make sure we understand what changes take place, and why.

The journey leads us on a path that ends up with a simple OData V4 service providing books and authors data, ultimately one that allows for books to have multiple authors, and authors to have written multiple books. But the important part of the journey is not that destination, it's the path we will take.

You can take this journey with whatever tools, IDEs, editors and command lines you feel comfortable with. 

If you're looking for a "turnkey" setup, then we recommend you use Microsoft VS Code which can then benefit from the dev container definition, which describes a container image containing everything you need, from the command line tools (and the ultimate shell environment itself, i.e. Bash, naturally), Node.js, and the Node.js-based SAP Cloud Application Programming Model development kit "@sap/cds-dk". 

The instructions here will assume you're using this approach, i.e. using VS Code and that you also have a container runtime (such as Docker Desktop) for VS Code to use.

> If your editor has an Auto Save facility (VS Code does), you should turn it off, mostly so you can make changes and decide when you want to observe the effects, and specifically because you'll need to make a coordinated change to a couple of files, and it's better if you make all the changes first and save them together afterwards.
>
> Here's what the setting looks like in VS Code:
>
> ![autosave off](assets/autosave-off.png)

There are some simple monitoring scripts in this repo, in the [utils/](./utils/) directory, to monitor for changes to files and to emit (and re-emit everytime anything changes) the EDMX (the OData metadata for the service) and the SQL DDL statements for the tables and views at the persistence layer. Also in the [utils/](./utils/) directory are a couple of simple CSV related scripts that we'll use.

Here are the steps. In most of the steps the observations that we make (on the EDMX, SQL and CAP server output) will be in a "Notes" subsection within that step.

* [01 Clone this repo and set up a new empty CAP project](#01-clone-this-repo-and-set-up-a-new-empty-cap-project)
* [02 Start with the basic persistence layer artifacts and set up the monitoring](#02-start-with-the-basic-persistence-layer-artifacts-and-set-up-monitoring)
* [03 Add an empty service](#03-add-an-empty-service)
* [04 Add the Books entity but not inside the service](#04-add-the-books-entity-but-not-inside-the-service)
* [05 Put the Books entity inside the service](#05-put-the-books-entity-inside-the-service)
* [06 Add the Authors entity inside the service](#06-add-the-authors-entity-inside-the-service)
* [07 Add a basic relationship with a to-one managed association, at the persistence layer](#07-add-a-basic-relationship-with-a-to-one-managed-association-at-the-persistence-layer)
* [08 Add the author_ID field to the Books CSV data](#08-add-the-author_id-field-to-the-books-csv-data)
* [09 Move the current to-one managed association from the persistence layer to the service layer](#09-move-the-current-to-one-managed-association-from-the-persistence-layer-to-the-service-layer)
* [10 Add a reverse to-many managed association from Authors to Books](#10-add-a-reverse-to-many-managed-association-from-authors-to-books)
* [11 Fix the to-many managed association](#11-fix-the-to-many-managed-association)
* [12 Attempt to follow the to-many managed association from author to books](#12-attempt-to-follow-the-to-many-managed-association-from-author-to-books)
* [13 Create a link entity as the basis for a many-to-many relationship](#13-create-a-link-entity-as-the-basis-for-a-many-to-many-relationship)
* [14 Relate each of the Books and Authors entities to the new link entity](#14-relate-each-of-the-books-and-authors-entities-to-the-new-link-entity)
* [15 Add the link entity to the service](#15-add-the-link-entity-to-the-service)
* [16 add data to the link entity to relate books and authors](#16-add-data-to-the-link-entity-to-relate-books-and-authors)
* [17 add a further author and book relationship to define co-authorship](#17-add-a-further-author-and-book-relationship-to-define-co-authorship)

## 01 Clone this repo and set up a new empty CAP project

Branch: `01-clone-this-repo-and-set-up-a-new-empty-cap-project`.

We'll be starting from scratch with a new, empty CAP project, within the context of this repo (as the simple monitoring scripts you'll use are in here). 

👉 Clone this repo now, and open it in VS Code:

```shell
git clone https://github.com/qmacro/managed-associations-in-cap
code managed-associations-in-cap
```

This should start up VS Code and open within it the new `managed-associations-in-cap/` directory containing a clone of this repo. Additionally, VS Code should notice the `.devcontainer/` directory and contents, and prompt you to re-open in a container. You should do this. 

👉 Once VS Code has re-opened things in the context of the defined container, open a new terminal and initialise a new CAP project directly in the directory you're now in:

```shell
cds init
```

This should create various files and directories.

## 02 Start with the basic persistence layer artifacts and set up monitoring

Branch: `02-start-with-the-basic-persistence-layer-artifacts-and-set-up-monitoring`.

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

* `./utils/monedmx` ("EDMX")
* `./utils/monsql` ("SQL")
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


## 03 Add an empty service

Branch: `03-add-an-empty-service`.

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

Within the main `Schema` section, there is an empty `EntityContainer`, and there are no `EntityType`s. 

SQL: No change.

SERVER: The message about no service definitions being found goes away and we see that it is serving service `Z` as lower case `z` (this is a CAP convention which can be overridden). At <http://localhost:4004> links to the standard OData service document and metadata document are shown, but there are no service endpoints. The metadata document content (at <http://localhost:4004/z/$metadata>) is the same as the EDMX above. The service document (<http://localhost:4004/z>) has no real content; the important part (the list of entitysets available, in the `value` property) is empty: 

```json
{
  "@odata.context": "$metadata",
  "@odata.metadataEtag": "W/\"vRN6ru2cTrbbf2J+uTFQ1q6pPvqg8m4ot2mI8a7HpqU=\"",
  "value": []
}
```

## 04 Add the Books entity but not inside the service

Branch: `04-add-the-books-entity-but-not-inside-the-service`.

👉 Add an entity specification in `srv/main.cds`, but not inside the `service` statement. The content of this file should now look like this:

```cds
using bookshop from '../db/schema';

service Z;

entity Books as projection on bookshop.Books;
```

### Notes

EDMX: This remains unchanged, as a basic and still empty service. Not surprisingly, as the entity we've just added wasn't within the context of the `Z` service (or any service).

SQL: A `CREATE VIEW` DDL stanza appears. Note that the name for the entity is not prefixed with any service name, i.e. it is `CREATE VIEW Books` and not `CREATE VIEW Z_Books`:

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

Views are most commonly used to represent the entity projections in a service. So from a persistence layer perspective, things are ready for this entity projection.

SERVER: There's no difference in the CAP server log output. Moreover, there's no sign of `Books` as a service endpoint at <http://localhost:4004/> (as it's not actually defined within the `Z` service, i.e. for the same reason why it's not showing in the EDMX either).

## 05 Put the Books entity inside the service

Branch: `05-put-the-books-entity-inside-the-service`.

👉 Now move the entity specification in `srv/main.cds` to within the `service` statement, so that the contents of `srv/main.cds` now look like this:

```cds
using bookshop from '../db/schema';

service Z {
  entity Books as projection on bookshop.Books;
}
```

### Notes

EDMX: Now the `Books` entity appears as an `EntityType` definition within the `Schema`, and the `EntityContainer` is no longer empty - it now contains an `EntitySet` defined that refers to that `EntityType`.

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

SERVER: There's still no difference in the CAP server log output (there wouldn't be, for a simple addition of an endpoint in a service). But at <http://localhost:4004> there's now a `Books` service endpoint shown. Selecting it (to make an OData query operation on the entityset, i.e. <http://localhost:4004/z/Books>) returns the data sourced from the CSV file, with ID and title values:

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

## 06 Add the Authors entity inside the service

Branch: `06-add-the-authors-entity-inside-the-service`.

👉 Add another entity specification within the service, for Authors, so that `srv/main.cds` now looks like this:

```cds
using bookshop from '../db/schema';

service Z {
  entity Books as projection on bookshop.Books;
  entity Authors as projection on bookshop.Authors;
}
```

### Notes

EDMX: A further `EntityType` and `EntitySet` pair appears, but note that there are no navigation properties between the two entities yet:

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

SQL: There's now a second CREATE VIEW DDL statement for the Authors entity in the service, also of course with the entity's name prefixed with the service name, i.e. `Z_Authors`:

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

SERVER: There's also now an `Authors` service endpoint shown at <http://localhost:4004>, i.e. <http://localhost:4004/z/Authors>, with this data:

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

## 07 Add a basic relationship with a to-one managed association, at the persistence layer

Branch: `07-add-a-basic-relationship-with-a-to-one-managed-association`.

👉 In `db/schema.cds`, add an `author` element (note the singular element name, not `authors` plural) to the `Books` entity. This is a managed association, specifically a (one-) to-one association. The resulting contents of `db/schema.cds` should look like this:

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

EDMX: Suddenly we can see relationships expressed in the OData entity data model. A `NavigationPropertyBinding` element appears within the `EntitySet` for `Books`, pointing to the `EntitySet` for `Authors`. 

Additionally, the `Books` `EntityType` gets a new `Property` which is `author_ID`, and also gets a `NavigationProperty` which has a `ReferentialConstraint` based on that property. Note that there's no change to the `Authors` `EntityType` definition at this point:

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

(See the OData documentation on [NavigationPropertyBinding](http://docs.oasis-open.org/odata/odata/v4.0/cos01/part3-csdl/odata-v4.0-cos01-part3-csdl.html#_Toc372793991) for more information.)

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

This `author_ID` element is created automatically by CAP; this is a small part of what managed associations are all about, abstracting the underlying persistence layer and doing the "foreign key thinking" for you.

SERVER: Nothing visibly changes at the service endpoint level, but the records (entities) in the `Books` entityset (<http://localhost:4004/z/Books>) now contain the new `author_ID` field. Don't get too excited yet, because right now the values are all `null` of course:

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

This suggests we need to add a new field to the `db/data/bookshop-Books.csv` file, with some corresponding data.

## 08 Add the author_ID field to the Books CSV data

Branch: `08-add-the-author_id-field-to-the-books-csv-data`.

👉 Open up yet another terminal, and use the script `./utils/csvgetdata` to retrieve the Books CSV (from the CSV data files in the [SAP-samples/cloud-cap-samples](https://github.com/SAP-samples/cloud-cap-samples/) repo) like this:

```shell
./utils/csvgetdata Books ID,title,author_ID
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

👉 Run this again, but this time redirect the output to the `db/data/bookshop-Books.csv` file:

```shell
./utils/csvgetdata Books ID,title,author_ID > db/data/bookshop-Books.csv
```

Now we have the values for `author_ID` in the Books data.

> You might want to leave this terminal around as you'll be running another script later on.

### Notes

EDMX: No change.

SQL: No change.

SERVER: The CAP server restarts, and now the `Books` entityset's records (at <http://localhost:4004/z/Books>) have values in the `author_ID` field:

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

This is enough to satisfy and support the basic relationship we have now between `Books` and `Authors`, which in turn means we can use OData's `$expand` system query option when requesting the `Books` entityset, to follow the `author` navigation property, i.e. <http://localhost:4004/z/Books?$expand=author>. 

The resulting resource (as usual, with OData V4, in a JSON representation), is where we can see the (one-) to-one relationship and where -- right now -- a book can have one and only one author:

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

Important: There is no change to the `Authors` entityset, and we cannot go the other way, i.e. we can not go from author to book. There is no navigation property available for that, as we can of course see from the definition of the `Authors` `EntityType` in the metadata document at <http://localhost:4004/z/$metadata>:

```xml
<EntityType Name="Authors">
  <Key>
    <PropertyRef Name="ID"/>
  </Key>
  <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
  <Property Name="name" Type="Edm.String"/>
</EntityType>
```

In fact, if we were to attempt to invent or guess at such a property and use it, in a call such as <http://localhost:4004/z/Authors?$expand=book> or <http://localhost:4004/z/Authors?$expand=books> then we'd get an error, of course:

```xml
<error xmlns="http://docs.oasis-open.org/odata/ns/metadata">
  <code>400</code>
  <message>Navigation property 'books' is not defined in type 'Z.Authors'</message>
</error>
```

But even this error teaches us something, or at least suggests something that is quite likely: that `$expand` needs a `NavigationProperty` to work. Errors are our friends!

> You may have noticed that the value of the author ID appeared twice in the JSON response, once as the value of the `author_ID` foreign key field created and handled by the managed association, and again as the value of the `ID` key field of the expanded entity. Here's an example where the author ID value `101` appears twice:
> 
> ```json
> {
>   "ID": 201,
>   "title": "Wuthering Heights",
>   "author_ID": 101,
>   "author": {
>     "ID": 101,
>     "name": "Emily Brontë"
>   }
> }
> ```
>
> Key fields are automatically emitted in the entities, but we can indirectly omit the `author_ID` field from the `Books` entity by adding a `$select` query option like this: <http://localhost:4004/z/Books?$expand=author&$select=title&$top=1> (just selecting the first entity to keep things short):
>
> ```json
> {
>   "@odata.context": "$metadata#Books(title,ID,author())",
>   "value": [
>     {
>       "title": "Wuthering Heights",
>       "ID": 201,
>       "author": {
>         "ID": 101,
>         "name": "Emily Brontë"
>       }
>     }
>   ]
> }
> ```

## 09 Move the current to-one managed association from the persistence layer to the service layer

Branch: `09-move-the-current-to-one-managed-association-from-the-persistence-layer-to-the-service-layer`.

Rather than continue to work at the `db/schema.cds` level, let's move our relationship enhancements up a layer, to the service layer, and store them in an "extension" file. 

👉 First, create a new, empty file `srv/extend.cds`. 

👉 Next, restart the two monitoring scripts `./utils/monedmx` and `./utils/monsql`. This is because they are based on [entr](https://eradman.com/entrproject/) which monitors changes to files, but not creation of new files, so the creation and subsequent editing of the new `srv/extend.cds` here wouldn't cause the EDMX and SQL output to be refreshed.

👉 Once you've restarted the EDMX and SQL monitors, carry out the following changes:

* Remove the `author` element from the `Books` entity in `db/schema.cds`, so the entity definition goes back to looking like this:
  ```cds
  entity Books {
    key ID : Integer;
    title  : String;
  }
  ```

* Add the element back in, but this time as part of the following in the new `srv/extend.cds` :
  ```cds
  using bookshop from '../db/schema';

  extend bookshop.Books with {
    author: Association to bookshop.Authors;
  }
  ```

  > Note that the association target must now be specified with the namespace prefix, as `bookshop.Authors`, and not just `Authors`.

👉 Save the changes to both files, ideally at the same time.


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

Beyond this minor change to the CAP server log output, there is no effective difference to the service, or the data available. We've just moved the definition of the (one-) to-one managed association to a separate file at the service layer, nothing more. 

> If you want to learn more about how to integrate and mash up services and definitions, you may wish to attend (or host) the [Service integration with SAP Cloud Application Programming Model](https://github.com/SAP-samples/cap-service-integration-codejam) SAP CodeJam - find out more at [So, You Want to Host a CodeJam! Everything you need to know](https://groups.community.sap.com/t5/sap-codejam-blog-posts/so-you-want-to-host-a-codejam-everything-you-need-to-know/ba-p/221415).

Incidentally, if you didn't manage to save both files at the same time, that's fine, it's just that you will have encountered one of two possible errors (both temporary) in the CAP server log output, depending on which file you saved first. Then again, errors are great, because we learn from them, so let's embrace them! Here are the possible errors you may have encountered:

* If you saved the removal of the `author:  Association to Authors;` line in the `db/schema.cds` file first, you may have seen the following error, because you'd removed the managed association, which had been responsible for the creation of the `author_ID` element (to act as a foreign key), and which would have therefore been removed, causing a CSV import error thus:
  ```log
  [ERROR] SQLITE_ERROR: table bookshop_Books has no column named author_ID in: 
  INSERT INTO bookshop_Books ( ID, title, author_ID ) VALUES ( ?, ?, ? )
  ```

* If you saved the contents of the new `srv/extend.cds` first, then you would have of course effectively defined an `author` element a second time on the same entity (`Books`, in the `bookshop` namespace), and would have caused the following error:
  ```log
  [ERROR] srv/extend.cds:4:3-9: Duplicate definition of element “author” (in entity:“bookshop.Books”/element:“author”)
  ```

## 10 Add a reverse to-many managed association from Authors to Books

Branch: `10-add-a-reverse-to-many-managed-association-from-authors-to-books`.

So far we can go from a book to the author of that book. So that we can also go from an author to the book(s) they wrote, we need to add a reverse association. Again, a managed association, but this time not a to-one but a a to-many managed association.

👉 In the `srv/extend.cds` file, add another `extend` stanza so the entire contents look like this (do not specify any `on` condition at this point):

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

> If you don't see the warnings described as follows, simply restart the `./utils/monedmx` and `./utils/monsql` scripts as described in the previous step.

EDMX: There are warnings when generating the EDMX, as follows:

```log
[WARNING] srv/extend.cds:8:3: An association can't have cardinality "to many" without an ON-condition (in entity:“bookshop.Authors”/element:“books”)
[WARNING] srv/main.cds:5:10: An association can't have cardinality "to many" without an ON-condition (in entity:“Z.Authors”/element:“books”)
```

See the [(One-)To-Many Associations](https://cap.cloud.sap/docs/guides/domain-modeling#to-many-associations) section of Capire for details. Both warnings relate to the same issue (the `Association to many bookshop.Books`), just from two different perspectives: 

* in the `srv/extend.cds` file
* in the `srv/main.cds` file

Despite these warnings, there have, though, been some additions to the metadata. 

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

* The type is specified as `Collection(Z.Books)`, because it's for this to-many association (i.e. the relationship is from a single thing to a collection of things)
* While there is a `ReferentialConstraint` defined for the already-existing to-one association from earlier (for `Books.author`):
    ```xml
    <NavigationProperty Name="author" Type="Z.Authors">
      <ReferentialConstraint Property="author_ID" ReferencedProperty="ID"/>
    </NavigationProperty>
    ```
  there is no `ReferentialConstraint` for this new to-many association.

Second, there is also an additional `Property` for the `books_ID` element that was created as a result of this new managed to-many association:

```xml
<Property Name="books_ID" Type="Edm.Int32"/>
```

Does this look right to you? Hold that thought.

SQL: The same warnings appear as did for the EDMX (and for the same reason, of course):

```log
[WARNING] srv/extend.cds:8:3: An association can't have cardinality "to many" without an ON-condition (in entity:“bookshop.Authors”/element:“books”)
[WARNING] srv/main.cds:5:10: An association can't have cardinality "to many" without an ON-condition (in entity:“Z.Authors”/element:“books”)
```

The DDL statements in the SQL now also have a new element `books_ID` both in the `CREATE_TABLE` statement for the `bookshop_Authors` table and for the `Z_Authors` view too:

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

Again, how do you think this additional `books_ID` element might work to bring about a (one-) to-many association from authors to books? 

SERVER: The `Authors` entityset records at <http://localhost:4004/z/Authors> now show that new `books_ID` element, and the value for each one is `null`:

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

Basically, as it stands, this to-many managed association isn't quite right. Given that there's only a single scalar value that can be specified for `books_ID`, how on earth could we relate an author to more than one book?

While we can logically see that this is not going to work, let's find out what happens if we try to actually use this new `NavigationProperty` that we have at the moment, i.e. this one:

```xml
<NavigationProperty Name="books" Type="Collection(Z.Books)"/>
```

We know that to follow such properties we can use the OData system query option `$expand`. 

👉 So try this: <http://localhost:4004/z/Authors?$expand=books>.

What we get is perhaps a little unexpected, but not an overall surprise:

```xml
<error xmlns="http://docs.oasis-open.org/odata/ns/metadata">
  <code>500</code>
  <message>SQLITE_ERROR: near ")": syntax error in: SELECT b.ID AS "b_ID", b.title AS "b_title", b.author_ID AS "b_author_ID", filterExpand.ID AS "filterExpand_ID" FROM Z_Books b INNER JOIN (SELECT DISTINCT ID FROM (SELECT a.ID AS ID FROM Z_Authors a ORDER BY a.ID COLLATE NOCASE ASC LIMIT 1000)) filterExpand ON ( )</message>
</error>
```

It stands to reason that this SQL expression that was constructed here to go from authors to books needs something for the `ON (...)` part of the filter expansion (right at the end of the expression). Are you wondering what might go in there? How could we find out?

Well, we could turn on debug output with the CAP server, via the [Minimalistic Logging Facade](https://cap.cloud.sap/docs/node.js/cds-log), specifically with the `DEBUG` environment variable, and then make a similar OData query operation but going the other way, where we know the relationship described by the `NavigationProperty` there is correct, i.e. includes a `ReferentialConstraint`:

```xml
<NavigationProperty Name="author" Type="Z.Authors">
  <ReferentialConstraint Property="author_ID" ReferencedProperty="ID"/>
</NavigationProperty>
```

👉 Stop the CAP server with Ctrl-C, and restart it, specifying the value `sql` for the [`DEBUG` environment variable](https://cap.cloud.sap/docs/node.js/cds-log#debug-env-variable) on the same line, like this:

```shell
DEBUG=sql cds watch
```

Immediately, in addition to all the normal log output, we also see this:

```log
[sqlite] - BEGIN 
[sqlite] - DROP table if exists cds_Model; 
[sqlite] - COMMIT 
[sqlite] - BEGIN 
[sqlite] - SELECT 1 from sqlite_master where name='cds_xt_Extensions' {}
[sqlite] - DROP VIEW IF EXISTS Z_Authors 
[sqlite] - DROP VIEW IF EXISTS Z_Books 
[sqlite] - DROP TABLE IF EXISTS bookshop_Authors 
[sqlite] - DROP TABLE IF EXISTS bookshop_Books 
[sqlite] - CREATE TABLE bookshop_Books (
  ID INTEGER NOT NULL,
  title NVARCHAR(5000),
  author_ID INTEGER,
  PRIMARY KEY(ID)
); 
[sqlite] - CREATE TABLE bookshop_Authors (
  ID INTEGER NOT NULL,
  name NVARCHAR(5000),
  books_ID INTEGER,
  PRIMARY KEY(ID)
); 
[sqlite] - CREATE VIEW Z_Books AS SELECT
  Books_0.ID,
  Books_0.title,
  Books_0.author_ID
FROM bookshop_Books AS Books_0; 
[sqlite] - CREATE VIEW Z_Authors AS SELECT
  Authors_0.ID,
  Authors_0.name,
  Authors_0.books_ID
FROM bookshop_Authors AS Authors_0; 
[sqlite] - COMMIT 
 > init from db/data/bookshop-Authors.csv
[sqlite] - BEGIN 
[sqlite] - INSERT INTO bookshop_Authors ( ID, name ) VALUES ( ?, ? ) [
  [ '101', 'Emily Brontë' ],
  [ '107', 'Charlotte Brontë' ],
  [ '150', 'Edgar Allen Poe' ],
  [ '170', 'Richard Carpenter' ]
]
 > init from db/data/bookshop-Books.csv
[sqlite] - INSERT INTO bookshop_Books ( ID, title, author_ID ) VALUES ( ?, ?, ? ) [
  [ '201', 'Wuthering Heights', '101' ],
  [ '207', 'Jane Eyre', '107' ],
  [ '251', 'The Raven', '150' ],
  [ '252', 'Eleonora', '150' ],
  [ '271', 'Catweazle', '170' ]
]
[sqlite] - COMMIT
```

👉 Now request the resource at <http://localhost:4004/z/Books?$expand=author>, and observe the log output, which should show something like this:

```log
[sqlite] - SELECT a.ID AS "a_ID", a.title AS "a_title", a.author_ID AS "a_author_ID", b.ID AS "b_ID", b.name AS "b_name", b.books_ID AS "b_books_ID" FROM Z_Books a LEFT JOIN Z_Authors b ON ( b.ID = a.author_ID ) ORDER BY a.ID COLLATE NOCASE ASC LIMIT 1000 []
```

We can see from this successful call that follows the relationship from books to authors that the content of the `ON (...)` is:

```sql
b.ID = a.author_ID
```

This is pretty much what we'd expect, i.e. the constraint in action. We don't have a constraint in the `ON (...)` part of the SQL expression generated for <http://localhost:4004/z/Authors?$expand=books> because the managed association declaration is incomplete.

## 11 Fix the to-many managed association

Branch: `11-fix-the-to-many-managed-association`.

The to-many managed association won't work for what we want, we can't relate an author to more than one book. The association is only half-baked at this point anyway, as we can see from the warnings that are emitted, and the error that occurs when we try to use it. 

Let's address that now, by adding the `on` condition mentioned in both the warning and in the error.

👉 Modify the to-many association in the `srv/extend.cds` so it looks like this:

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

EDMX: The warnings have now gone. There are no further changes to the details of the `Authors` `EntitySet`, it is as it was before we added the `on` condition:

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

The `Books` `EntityType`, i.e. the target of this (one-) to-many managed association, now has a new attribute `Partner="books"` in its existing `NavigationProperty`:

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

has now disappeared again. This makes sense, in that it absolutely didn't make sense to have a `book_ID` property to link an author to potentially multiple books. 

SQL: Correspondingly, the `book_ID` element has now disappeared again from both the authors table and view DDL statements:

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

The warnings have also gone from here too.

SERVER: No change.

## 12 Attempt to follow the to-many managed association from author to books

Branch: `12-attempt-to-follow-the-to-many-managed-association-from-author-to-books`.

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

👉 First, make a simple OData query operation to retrieve the Authors entityset <http://localhost:4004/z/Authors>:

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

This reflects exactly the fields and data within the `db/data/bookshop-Authors.csv` file. There's no `book_ID` any more.

👉 Now use the `$expand` system query option to follow the navigation property (this one: `<NavigationProperty Name="books" Type="Collection(Z.Books)" Partner="author"/>`) <http://localhost:4004/z/Authors?$expand=books> - this should return something like this:

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

Great! 

Of course, this is a fully functional navigation property so we can use more involved OData query operations.

👉 Try these (somewhat contrived) examples:

* Listing all authors, showing any of their books that have titles that contain "the" [http://localhost:4004/z/Authors?$expand=books($filter=contains(title,'the'))](http://localhost:4004/z/Authors?$expand=books($filter=contains(title,%27the%27)))
* Listing all authors, showing their books but just the title information <http://localhost:4004/z/Authors?$expand=books($select=title)>
* Authors that have written more than one book [http://localhost:4004/z/Authors?$filter=books/$count gt 1](http://localhost:4004/z/Authors?$filter=books/$count%20gt%201)
* Authors that have written more than one book, listing what they wrote [http://localhost:4004/z/Authors?$filter=books/$count gt 1&$expand=books($select=title)](http://localhost:4004/z/Authors?$filter=books/$count%20gt%201&$expand=books($select=title))
* And just a final (and slightly extreme) example of multiple nested expands [http://localhost:4004/z/Authors?$filter=books/$count gt 1&$expand=books($expand=author($expand=books($expand=author)))](http://localhost:4004/z/Authors?$filter=books/$count%20gt%201&$expand=books($expand=author($expand=books($expand=author)))) which returns this:
  ```json
  {
    "@odata.context": "$metadata#Authors(books(author(books(author()))))",
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

## 13 Create a link entity as the basis for a many-to-many relationship

Branch: `13-create-a-link-entity-as-the-basis-for-a-many-to-many-relationship`.

Let's now move on from (one-) to-one and (one-) to-many relationships ... to a many-to-many relationship.

While CDS doesn't currently directly support many-to-many relationships (see [Many-to-Many Associations](https://cap.cloud.sap/docs/guides/domain-modeling#many-to-many-associations)), they can be achieved by using a so-called "link entity" to bind two (one) to-many managed associations together.

👉 In the `srv/extend.cds` file, add a new entity `Books_Authors` so that the contents look as follows:

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

## 14 Relate each of the Books and Authors entities to the new link entity

Branch: `14-relate-each-of-the-books-and-authors-entities-to-the-new-link-entity`.

Think of the link entity as a central "plumbing" facility, that just has a list of (in this case) pairs of numeric author and book IDs, linking authors and books. Then, from either side, we need to link the `Books` entity and `Authors` entity to that central plumbing facility, i.e. the link entity.

Right now, the relationships defined in `srv/extend.cds`, going from `bookshop.Books` and going from `bookshop.Authors`, go to each other. In other words, these are the two managed association definitions (see just earlier for the entire contents):

* Here's the current (one-) to-one managed association:
  ```cds
  extend bookshop.Books with {
    author: Association to bookshop.Authors;
  }
  ```

* And here's the current (one-) to-many managed association:
  ```cds
  extend bookshop.Authors with {
    books: Association to many bookshop.Books on books.author = $self;
  }
  ```

Now we need to make a change so that they no longer point to each other, but instead point to the corresponding elements in the new link entity `Books_Authors`. 

👉 Modify the `srv/extend.cds` so the entire contents look like this (note that each of the element names are plural now):

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

The message is fairly clear, although it's best to read this one from back to front to properly understand it. 

What it's saying is that because `Books_Authors` is not included in the `Z` service definition (which is true, we haven't added anything inside the `service Z { ... }` to include it yet) a navigation property binding at the OData level cannot be generated. This is because there isn't anywhere for it to point - there is no target entity type for this link entity, and consequently no entityset either as a target for the navigation.

As a result of this omission, all relationships (in the form of navigation properties) have disappeared, and we're back to almost where we started, with just simple properties for the book IDs and titles, and the author IDs and names:

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

This makes sense, as there is no longer any `author_ID`. So before moving on to the next step, let's get rid of that from the CSV file `db/data/bookshop-Books.csv`. 

And that's not wasted effort that we'll have to shortly undo, because when we do want to rebuild that relationship (between books and authors), we won't be doing it in the `db/data/bookshop-Books.csv` file, we'll be doing it in a new CSV file that will correspond to the link entity.

To get rid of the `author_ID` field from the CSV file, you can use the `csvdelfield` script in the `utils/` directory. This is perhaps a little overkill for a CSV file with only a handful of records, but it could be useful for larger files, or files where you want to remove a field that is in the middle and difficult to edit out manually.

👉 At a terminal prompt (for example the one you used earlier for the `./utils/csvgetdata` script), try it out, specifying the name of the CSV file, like this:

```shell
./utils/csvdelfield db/data/bookshop-Books.csv
```
It should show a list of current CSV fields in the file, like this:

```log
ID,title,author_ID
```

👉 Now re-run it, this time specifying the `author_ID` field that we want to delete. WARNING: this will actually modify the CSV file contents directly:

```shell
./utils/csvdelfield db/data/bookshop-Books.csv author_ID
```

As well as modifying the CSV file, it will also output the new content directly:

```csv
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

## 15 Add the link entity to the service

We need to address the fact that we cannot navigate at all between the `Books` and `Authors` entities. We know why that is, from the warning in the previous step, which told us that no navigation properties were generated. The warning also told us why - we don't have the link entity in the service, so it was effectively "not available" for the relationship definitions.

Let's fix that now. We could simply add it as a third item inside the service definition in the `srv/main.cds` file, which currently looks like this:

```cds
using bookshop from '../db/schema';

service Z {
  entity Books as projection on bookshop.Books;
  entity Authors as projection on bookshop.Authors;
}
```

But with our `srv/extend.cds` file, we're already thinking philosophically about treading lightly upon entity and service definitions that already exist, and instead extending and modifying them from elsewhere. 

In this file, we've already used the `extend` keyword to add elements to existing entities (adding `authors` to `bookshop.Books`, and `books` to `bookshop.Authors`). So let's continue on that path and add a further `extend` keyword, but this time not for an entity, but for a service. Our `Z` service.

In order to successfully reference that `Z` service, which is defined in `srv/main.cds`, we need to bring the definition in.

👉 So, in `srv/extend.cds`: 

* add a `using` line to bring in the definitions in `srv/main.cds`
* add an `extend service` clause to add the link entity to the `Z` service

The contents should end up looking like this:

```cds
using bookshop from '../db/schema';
using from './main';

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

extend service Z with {
  entity LinkEntity as projection on Books_Authors;
}
```

That's all we need to do here.

### Notes

EDMX: The warnings about no navigation properties being generated now have disappeared. There is, though, a new warning that appears:

```log
[WARNING] srv/extend.cds:18:10: Expected entity to have a primary key (in entity:“Z.LinkEntity”)
```

This is fine, we're not wanting to use this link entity as a "normal" entity, so we can ignore this warning.

More interestingly, relationships are back in the EDMX, and they're back with a vengeance!

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
        <EntitySet Name="LinkEntity" EntityType="Z.LinkEntity">
          <NavigationPropertyBinding Path="book" Target="Books"/>
          <NavigationPropertyBinding Path="author" Target="Authors"/>
        </EntitySet>
        <EntitySet Name="Books" EntityType="Z.Books">
          <NavigationPropertyBinding Path="authors" Target="LinkEntity"/>
        </EntitySet>
        <EntitySet Name="Authors" EntityType="Z.Authors">
          <NavigationPropertyBinding Path="books" Target="LinkEntity"/>
        </EntitySet>
      </EntityContainer>
      <EntityType Name="LinkEntity">
        <NavigationProperty Name="book" Type="Z.Books" Partner="authors">
          <ReferentialConstraint Property="book_ID" ReferencedProperty="ID"/>
        </NavigationProperty>
        <Property Name="book_ID" Type="Edm.Int32"/>
        <NavigationProperty Name="author" Type="Z.Authors" Partner="books">
          <ReferentialConstraint Property="author_ID" ReferencedProperty="ID"/>
        </NavigationProperty>
        <Property Name="author_ID" Type="Edm.Int32"/>
      </EntityType>
      <EntityType Name="Books">
        <Key>
          <PropertyRef Name="ID"/>
        </Key>
        <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
        <Property Name="title" Type="Edm.String"/>
        <NavigationProperty Name="authors" Type="Collection(Z.LinkEntity)" Partner="book"/>
      </EntityType>
      <EntityType Name="Authors">
        <Key>
          <PropertyRef Name="ID"/>
        </Key>
        <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
        <Property Name="name" Type="Edm.String"/>
        <NavigationProperty Name="books" Type="Collection(Z.LinkEntity)" Partner="author"/>
      </EntityType>
    </Schema>
  </edmx:DataServices>
</edmx:Edmx>
```

Here's a few pointers that will help you [stare at](https://qmacro.org/blog/posts/2017/02/19/the-beauty-of-recursion-and-list-machinery/#initialrecognition) the XML and take it all in.

Taking the `EntityType`s first:

* There's now a new `EntityType` for the `LinkEntity`. This consists purely of a couple of `NavigationProperty` elements each paired with a sibling `Property` element for the `_ID` style field generated through the managed association definition.
* Each of the `Books` and `Authors` `EntityTypes` now has a `NavigationProperty` that points to the `LinkEntity`, specifically in a collection (i.e. a to-many) context.

Now looking at the content of the `EntityContainer`:

* Instead of just two simple `EntitySet`s for `Books` and `Authors` that had no relation to each other (this is what we had in the previous step as a result of the failure to generate navigation properties), we now have a beautifully balanced relationship between those `Books` and `Authors` `EntitySet`s, via a new, third `EntitySet` for our `LinkEntity`. This third `EntitySet` has `NavigationPropertyBinding`s to each of `Books` and `Authors` targets.

SQL: While the change to the SQL is not as dramatic, it's still important to look at. What's different is that there's now a new DDL statement to create the view that corresponds to the link entity. The view is called `Z_LinkEntity`, i.e. with a `Z` prefix (remember that the `LinkEntity` entity lives in the `Z` service, just like the `Books` and `Authors` entities.

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

CREATE VIEW Z_LinkEntity AS SELECT
  Books_Authors_0.book_ID,
  Books_Authors_0.author_ID
FROM Books_Authors AS Books_Authors_0;

CREATE VIEW Z_Books AS SELECT
  Books_0.ID,
  Books_0.title
FROM bookshop_Books AS Books_0;

CREATE VIEW Z_Authors AS SELECT
  Authors_0.ID,
  Authors_0.name
FROM bookshop_Authors AS Authors_0;
```

SERVER: There is no discernible difference in the log output from the CAP server. But what we can see at <http://localhost:4004> is that there's now a new, third service endpoint: <http://localhost:4004/z/LinkEntity>. The OData entityset resource at this endpoint is currently empty, as we can see from the JSON representation that is returned (we'll add data in the next step):

```json
{
  "@odata.context": "$metadata#LinkEntity",
  "value": []
}
```

Not only that, but now that the relationships are back in the EDMX, we can follow the relationships from books to authors, and vice versa, by using the OData system query option `$expand` as normal:

* For looking at authors of books with <http://localhost:4004/z/Books?$expand=authors>, we get:
  ```json
  {
    "@odata.context": "$metadata#Books(authors())",
    "value": [
      {
        "ID": 201,
        "title": "Wuthering Heights",
        "authors": []
      },
      {
        "ID": 207,
        "title": "Jane Eyre",
        "authors": []
      },
      {
        "ID": 251,
        "title": "The Raven",
        "authors": []
      },
      {
        "ID": 252,
        "title": "Eleonora",
        "authors": []
      },
      {
        "ID": 271,
        "title": "Catweazle",
        "authors": []
      }
    ]
  }
  ```

* For looking at books of authors with <http://localhost:4004/z/Authors?$expand=books>, we get:
  ```json
  {
    "@odata.context": "$metadata#Authors(books())",
    "value": [
      {
        "ID": 101,
        "name": "Emily Brontë",
        "books": []
      },
      {
        "ID": 107,
        "name": "Charlotte Brontë",
        "books": []
      },
      {
        "ID": 150,
        "name": "Edgar Allen Poe",
        "books": []
      },
      {
        "ID": 170,
        "name": "Richard Carpenter",
        "books": []
      }
    ]
  }
  ```

There's no data in these followed navigation properties, because we removed the only link between the two entities when we removed the `author_ID` field from the data in the previous step. 

But notice, before we continue, that the value of the navigation property `authors` is an array. Not a scalar, like it was when we had `author_ID`, i.e. before we went from just a one-to-many relationship between authors and books to where we are now, where we have a many-to-many relationship. And it's a similar situation for the `books` navigation property in the records of the `Authors` entityset too.

## 16 Add data to the link entity to relate books and authors

Branch: `16-add-data-to-the-link-entity-to-relate-books-and-authors`.

The `Books_Authors` link entity is represented at the persistence layer with a simple table which we know is defined like this:

```sql
CREATE TABLE Books_Authors (
  book_ID INTEGER,
  author_ID INTEGER
);
```

So we can now relate books and authors by defining pairs of IDs in a new CSV file `db/data/Books_Authors.csv`. The name follows the usual convention, even though it looks a little different to the names of the other CSV files here; it is the namespace and entity name, but as there's no namespace that contextualises the entity here, there's no `<namespace>-` prefix part in the filename. 

> Remember that the entity (`entity Books_Authors { ... }`) is defined in the `srv/extend.cds` file where there's no `namespace` declaration.

Let's start by restoring the relationships we had before, where: 

* Charlotte Brontë wrote Wuthering Heights
* Emily Brontë wrote Jane Eyre
* Richard Carpenter wrote Catweazle
* Edgar Allen Poe wrote Eleonora and also wrote The Raven (a poem, as it happens)

👉 Create the new file `db/data/Books_Authors.csv` and add the following to it:

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

Note that there is no author name information shown, we just get author ID information. That's because the author name is one step further on. Right now, we can see this query and result as like jumping half way across a stream to a stepping stone in the middle, which represents the link entity. To get to the other side, we need to take a second jump.

We can use the power of OData V4 to make the second jump so that we effectively cover both steps in one go, from `Authors` to `Books_Authors` to `Books`, like this: [http://localhost:4004/z/Authors?$expand=books($expand=book)](http://localhost:4004/z/Authors?$expand=books($expand=book)), which will emit:

```json
{
  "@odata.context": "$metadata#Authors(books(book()))",
  "value": [
    {
      "ID": 101,
      "name": "Emily Brontë",
      "books": [
        {
          "book_ID": 201,
          "author_ID": 101,
          "book": {
            "ID": 201,
            "title": "Wuthering Heights"
          }
        }
      ]
    },
    {
      "ID": 107,
      "name": "Charlotte Brontë",
      "books": [
        {
          "book_ID": 207,
          "author_ID": 107,
          "book": {
            "ID": 207,
            "title": "Jane Eyre"
          }
        }
      ]
    },
    {
      "ID": 150,
      "name": "Edgar Allen Poe",
      "books": [
        {
          "book_ID": 251,
          "author_ID": 150,
          "book": {
            "ID": 251,
            "title": "The Raven"
          }
        },
        {
          "book_ID": 252,
          "author_ID": 150,
          "book": {
            "ID": 252,
            "title": "Eleonora"
          }
        }
      ]
    },
    {
      "ID": 170,
      "name": "Richard Carpenter",
      "books": [
        {
          "book_ID": 271,
          "author_ID": 170,
          "book": {
            "ID": 271,
            "title": "Catweazle"
          }
        }
      ]
    }
  ]
}
```

## 17 Add a further author and book relationship to define co-authorship

Branch: `17-add-a-further-author-and-book-relationship-to-define-co-authorship`.

As a final test, let's create a fictional collaboration between Ellis Bell and Emily Brontë. Ellis Bell was the pseudonym under which Emily Brontë wrote Wuthering Heights, so it sort of makes sense. Or maybe it doesn't. Anyway. 

👉 Add a new record to the end of `db/data/bookshop-Authors.csv` to represent Ellis Bell, so it looks like this:

```csv
ID,name
101,Emily Brontë
107,Charlotte Brontë
150,Edgar Allen Poe
170,Richard Carpenter
102,Ellis Bell
```

👉 Also add a new record to the end of `db/data/Books_Authors.csv` to link book Wuthering Heights (ID 201) with author Ellis Bell (ID 102), so it looks like this:

```csv
book_ID,author_ID
201,101
207,107
251,150
252,150
271,170
201,102
```

👉 Now check that both Emily Brontë and Ellis Bell appear as authors, with [http://localhost:4004/z/Authors?$search=Ellis OR Emily](http://localhost:4004/z/Authors?$search=Ellis%20OR%20Emily) for example:

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

👉 And now check that Wuthering Heights is now recorded as being co-written by both authors, with [http://localhost:4004/z/Books?$filter=title eq 'Wuthering Heights'&$expand=authors($expand=author)](http://localhost:4004/z/Books?$filter=title%20eq%20%27Wuthering%20Heights%27&$expand=authors($expand=author)):

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

We now have a fully functioning many-to-many relationship set up between our books and our authors, built with a pair of (one-) to-many managed associations linked together with a link entity. 

Great work!
