# Flow

## Monitoring setup

Run the following in separate terminal panes:

* `./util/monedmx` ("EDMX")
* `./util/monsql` ("SQL")
* `cds watch` ("SERVER")

## Starting point

Start with just `Books` and `Authors` defined as entities in `db/schema.cds`, with no relationships between them. Basic CSV data. No services defined.

**`db/schema.cds`**

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

**`srv/main.cds`**

```cds
using bookshop from '../db/schema';
```

**`db/data/bookshop-Books.csv`**

```csv
ID,title
201,Wuthering Heights
207,Jane Eyre
251,The Raven
252,Eleonora
271,Catweazle
```

**`db/data/bookshop-Authors.csv`**

```csv
ID,name
101,Emily Brontë
107,Charlotte Brontë
150,Edgar Allen Poe
170,Richard Carpenter
```

### Notes

EDMX: Error "There are no service definitions found at all in given model(s).".

SQL: Basic DDL for creating TABLE artifacts only (no views), and there are just the basic fields:

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

SERVER: Message "No service definitions found in loaded models. Waiting for some to arrive...".

## Add empty service

Add `service Z;` (capital `Z`) to `srv/main.cds` so that it becomes:

**`srv/main.cds`**

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

SERVER: Started. Serves capital `Z` as lower case `z`. In browser, shows service and metadata document links, but there are no service endpoints. Metadata document as EDMX above. Service document has no real content:

```json
{
  "@odata.context": "$metadata",
  "@odata.metadataEtag": "W/\"vRN6ru2cTrbbf2J+uTFQ1q6pPvqg8m4ot2mI8a7HpqU=\"",
  "value": []
}
```

## Add Books entity but not inside the service

Add an entity specification in `srv/main.cds` but not inside the `service` statement.

**`srv/main.cds`**

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

## Put Books entity inside the service

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


