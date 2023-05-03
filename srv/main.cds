using bookshop from '../db/schema';

service handsonsapdev {

    entity Books as projection on bookshop.Books;
    entity Authors as projection on bookshop.Authors;

}