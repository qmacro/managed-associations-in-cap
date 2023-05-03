using bookshop from '../db/schema';

extend bookshop.Books with {
  author: Association to bookshop.Authors;
}

extend bookshop.Authors with {
  books: Association to many bookshop.Books on books.author = $self;
}