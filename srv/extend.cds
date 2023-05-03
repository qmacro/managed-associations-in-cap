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
