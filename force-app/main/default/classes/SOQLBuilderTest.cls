@IsTest
private class SOQLBuilderTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testFieldSelections() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('firstName');
        builder.selectField(Schema.Contact.SObjectType.fields.LastName);
        builder.selectFields(new Set<String>{'acCounTId', 'account.name'});
        builder.selectFields(new List<String>{'homePhonE', 'fAX'});
        builder.selectFields(new List<Schema.SObjectField>{Contact.Email, Contact.Title } );

        Set<String> selectedFields = new Set<String>();
        for (SOQLBuilder.QueryField qField : builder.getSelectedFields()) {
            selectedFields.add(qField.toString());
        }

        System.assertEquals(
            new Set<String> {
                'FirstName',
                'LastName',
                'AccountId',
                'Account.Name',
                'HomePhone',
                'Fax',
                'Email',
                'Title'
            },
            selectedFields
        );
    }

    @IsTest
    static void testSimpleFieldSelection() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('NAMe').selectFields( new Set<String>{'naMe', 'email'});
        String query = builder.toSOQL();
        System.assert(Pattern.matches('SELECT.*Name.*FROM.*', query), 'Expected Name field in query, got ' + query);
        System.assert(Pattern.matches('SELECT.*Email.*FROM.*', query), 'Expected Name field in query, got ' + query);
        builder.setLimit(100);
        System.assertEquals(100, builder.getLimit());
        System.assert(builder.toSOQL().endsWithIgnoreCase('LIMIT ' + builder.getLimit()), 'Failed to respect limit clause:' + builder.toSOQL() );
    }

    @IsTest
    static void testSimpleFieldCondition() {
        String whereClause = 'name = \'test\'';
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('name');
        builder.selectField('email');
        builder.setCondition(whereClause);
        System.assertEquals(whereClause, builder.getCondition());
        String query = builder.toSOQL();
        System.assert(query.endsWith('WHERE name = \'test\''), 'Query should have ended with a filter on name, got: ' + query);
    }

    @IsTest
    static void testDuplicateFieldSelection() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('NAMe').selectFields( new Set<String>{'naMe', 'email'});
        String query = builder.toSOQL();
        System.assertEquals(1, query.countMatches('Name'), 'Expected one name field in query: ' + query);
    }

    @IsTest
    static void testEqualityCheck() {
        SOQLBuilder builder1 = new SOQLBuilder(Contact.SObjectType);
        SOQLBuilder builder2 = new SOQLBuilder(Contact.SObjectType);
        System.assertEquals(builder1, builder2);
        builder1.selectField('name');
        System.assertNotEquals(builder1, builder2);
        builder2.selectField('NAmE');
        System.assertEquals(builder1, builder2);
        builder1.selectField('name')
            .selectFields(new Set<String>{'NAME', 'name'})
            .selectFields(new Set<Schema.SObjectField>{Contact.Name, Contact.Name});
        System.assertEquals(builder1, builder2);
    }

    @IsTest
    static void testNonReferenceField() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        SOQLBuilder.NonReferenceFieldException e;
        try {
            builder.selectField('name.title');
        } catch (SOQLBuilder.NonReferenceFieldException ex) {
            e = ex;
        }

        System.assertNotEquals(NULL, e, 'Cross-object notation on a non-reference field should throw NonReferenceFieldException.');
    }

    @IsTest
    static void testInvalidCrossObjectField() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        SOQLBuilder.InvalidFieldException e;
        try {
            builder.selectField('account.NOT_A_REAL_FIELD');
        } catch (SOQLBuilder.InvalidFieldException ex) {
            e = ex;
        }

        System.assertNotEquals(NULL, e, 'Cross-object notation on a non-reference field should throw NonReferenceFieldException.');
    }

    @IsTest
    static void testInvalidFieldTests() {
        List<SOQLBuilder.InvalidFieldException> exceptions = new List<SOQLBuilder.InvalidFieldException>();
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);

        try {
            builder.selectField('Not_a_field');
        } catch (SOQLBuilder.InvalidFieldException e) {
            exceptions.add(e);
        }

        try {
            builder.selectFields(new Set<String>{'Not_a_field', 'alsoNotReal'});
        } catch(SOQLBuilder.InvalidFieldException e) {
            exceptions.add(e);
        }
        try {
            builder.selectFields(new Set<Schema.SObjectField>{NULL});
        } catch (SOQLBuilder.InvalidFieldException e){
            exceptions.add(e);
        }
        try {
            builder.selectFields( new List<Schema.SObjectField>{NULL, Contact.title});
        } catch (SOQLBuilder.InvalidFieldException e) {
            exceptions.add(e);
        }
        System.assertEquals(4, exceptions.size());
    }

    @IsTest
    static void testOrdering() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('Name');
        builder.selectField('Email');
        builder.setCondition('Name = \'test\'');
        builder.addOrdering(
            new SOQLBuilder.Ordering('Contact', 'Name', SOQLBuilder.SortOrder.ASCENDING)
        ).addOrdering(new SOQLBuilder.Ordering('Contact', 'CreatedDATE', SOQLBuilder.SortOrder.DESCENDING));

        String query = builder.toSOQL();

        System.assertEquals(2, builder.getOrderings().size());
        System.assertEquals('Name', builder.getOrderings()[0].getFields()[0].getDescribe().getName());
        System.assertEquals(SOQLBuilder.SortOrder.DESCENDING, builder.getOrderings()[1].getDirection() );

        System.assert( Pattern.matches('SELECT.*Name.*FROM.*', query), 'Expected Name field in query, got ' + query);
        System.assert( Pattern.matches('SELECT.*Email.*FROM.*', query), 'Expected Name field in query, got ' + query);
    }

    @IsTest
    static void testAddOrdering() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('Name');
        builder.selectField('Email');
        builder.setCondition('Name = \'test\'');

        //test base method with ordering by OwnerId Descending
        builder.addOrdering(new SOQLBuilder.Ordering('Contact', 'OwnerId', SOQLBuilder.SortOrder.DESCENDING));

        System.assertEquals(1, builder.getOrderings().size());

        System.assertEquals(
            Schema.Contact.SObjectType.fields.OwnerId, builder.getOrderings()[0].getFields()[0],
            'Unexpected order field - should have been resolved from the field OwnerId'
        );

        System.assertEquals(
            SOQLBuilder.SortOrder.DESCENDING,
            builder.getOrderings()[0].getDirection(),
            'Unexpected order direction.'
        );

        //test method overload with ordering by LastModifiedDate Ascending
        builder.addOrdering('LastModifiedDate', SOQLBuilder.SortOrder.ASCENDING, true);

        System.assertEquals(2, builder.getOrderings().size());

        System.assertEquals(
            Schema.Contact.SObjectType.fields.LastModifiedDate,
            builder.getOrderings()[1].getFields()[0],
            'Unexpected order field - should have been resolved from the field LastModifiedDate'
        );

        System.assertEquals(
            SOQLBuilder.SortOrder.ASCENDING,
            builder.getOrderings()[1].getDirection(),
            'Unexpected order direction.'
        );

        //test method overload with ordering by CreatedDate Descending
        builder.addOrdering(Contact.CreatedDate, SOQLBuilder.SortOrder.DESCENDING, true);

        System.assertEquals(3, builder.getOrderings().size());

        System.assertEquals(
            Schema.Contact.SObjectType.fields.CreatedDate,
            builder.getOrderings()[2].getFields()[0],
            'Unexpected order field - should have been resolved from the field CreatedDate'
        );

        System.assertEquals(
            SOQLBuilder.SortOrder.DESCENDING,
            builder.getOrderings()[2].getDirection(),
            'Unexpected order direction.'
        );

        //test method overload with ordering by CreatedBy.Name Descending
        builder.addOrdering('CreatedBy.Name', SOQLBuilder.SortOrder.DESCENDING);

        System.assertEquals(4, builder.getOrderings().size());

        System.assertEquals(
            SOQLBuilder.SortOrder.DESCENDING,
            builder.getOrderings()[3].getDirection(),
            'Unexpected order direction.'
        );

        //test method overload with ordering by Birthdate Ascending
        builder.addOrdering(Contact.Birthdate, SOQLBuilder.SortOrder.ASCENDING);

        System.assertEquals(5, builder.getOrderings().size());

        System.assertEquals(
            Schema.Contact.SObjectType.fields.Birthdate,
            builder.getOrderings()[4].getFields()[0],
            'Unexpected order field - should have been resolved from the field Birthdate'
        );

        System.assertEquals(
            SOQLBuilder.SortOrder.ASCENDING,
            builder.getOrderings()[4].getDirection(),
            'Unexpected order direction.'
        );

    }

    @IsTest
    static void testInvalidFieldString() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('name');
        Exception e;
        try {
            builder.selectField('not_a__field');
        } catch (SOQLBuilder.InvalidFieldException ex) {
            e = ex;
        }
        System.assertNotEquals(NULL, e);
    }

    @IsTest
    static void testInvalidFieldNullToken() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('name');
        Exception e;
        Schema.SObjectField token = NULL;
        try {
            builder.selectField(token);
        } catch (SOQLBuilder.InvalidFieldException ex) {
            e = ex;
        }
        System.assertNotEquals(NULL, e);
    }

    @IsTest
    static void testInvalidFieldsNullToken(){
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('name');
        Exception e;
        List<Schema.SObjectField> token = new List<Schema.SObjectField>{NULL};
        try {
            builder.selectFields(token);
        } catch (SOQLBuilder.InvalidFieldException ex) {
            e = ex;
        }
        System.assertNotEquals(NULL, e);
    }

    @IsTest
    static void testAddChildQueriesWithChildRelationshipSuccess() {
        Account acct = new Account();
        acct.Name = 'testchildqueriesacct';
        insert acct;

        Contact cont = new Contact();
        cont.FirstName = 'test';
        cont.LastName = 'test';
        cont.AccountId = acct.Id;
        insert cont;

        Task tsk = new Task();
        tsk.WhoId = cont.Id;
        tsk.Subject = 'test';
        tsk.ActivityDate = System.today();
        insert tsk;

        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('name').selectField('Id').setCondition('name like \'%test%\'').addOrdering('CreatedDate', SOQLBuilder.SortOrder.DESCENDING, true);
        Schema.DescribeSObjectResult descResult = Contact.SObjectType.getDescribe();
        //explicitly assert object accessibility when creating the subselect
        builder.subselectQuery('Tasks', true).selectField('Id').selectField('Subject').setCondition(' IsDeleted = false ');
        List<SOQLBuilder> queries = builder.getSubselectQueries();
        System.assert(queries != NULL);
        List<Contact> contacts = Database.query(builder.toSOQL());
        System.assert(contacts != NULL && contacts.size() == 1);
        System.assert(contacts[0].Tasks.size() == 1);
        System.assert(contacts[0].Tasks[0].Subject == 'test');
    }

    @IsTest
    static void testAddChildQueriesWithChildRelationshipObjCheckIsAccessibleSuccess() {
        Account acct = new Account();
        acct.Name = 'testchildqueriesacct';
        insert acct;

        Contact cont = new Contact();
        cont.FirstName = 'test';
        cont.LastName = 'test';
        cont.AccountId = acct.Id;
        insert cont;

        Task tsk = new Task();
        tsk.WhoId = cont.Id;
        tsk.Subject = 'test';
        tsk.ActivityDate = System.today();
        insert tsk;

        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('name').selectField('Id').setCondition( 'name like \'%test%\'' ).addOrdering('CreatedDate', SOQLBuilder.SortOrder.DESCENDING, true);
        Schema.DescribeSObjectResult descResult = Contact.SObjectType.getDescribe();
        Schema.ChildRelationship relationship;
        for (Schema.ChildRelationship childRow : descResult.getChildRelationships()){
            //occasionally on some standard objects (Like Contact child of Contact) do not have a relationship name.
            //if there is no relationship name, we cannot query on it, so throw an exception.
            if (childRow.getRelationshipName() == 'Tasks') {
                relationship = childRow;
            }
        }
        //explicitly assert object accessibility when creating the subselect
        builder.subselectQuery(relationship, true).selectField('Id').selectField('Subject').setCondition(' IsDeleted = false ');
        List<SOQLBuilder> queries = builder.getSubselectQueries();
        System.assert(queries != NULL);
        List<Contact> contacts = Database.query(builder.toSOQL());
        System.assert(contacts != NULL && contacts.size() == 1);
        System.assert(contacts[0].Tasks.size() == 1);
        System.assert(contacts[0].Tasks[0].Subject == 'test');
    }

    @IsTest
    static void testAddChildQueriesWithChildRelationshipObjSuccess() {
        Account acct = new Account();
        acct.Name = 'testchildqueriesacct';
        insert acct;

        Contact cont = new Contact();
        cont.FirstName = 'test';
        cont.LastName = 'test';
        cont.AccountId = acct.Id;
        insert cont;

        Task tsk = new Task();
        tsk.WhoId = cont.Id;
        tsk.Subject = 'test';
        tsk.ActivityDate = System.today();
        insert tsk;

        SOQLBuilder qf = new SOQLBuilder(Contact.SObjectType);
        qf.selectField('name').selectField('Id').setCondition('name like \'%test%\'').addOrdering('CreatedDate', SOQLBuilder.SortOrder.DESCENDING, true);
        Schema.DescribeSObjectResult descResult = Contact.SObjectType.getDescribe();
        Schema.ChildRelationship relationship;
        for (Schema.ChildRelationship childRow : descResult.getChildRelationships()) {
            //occasionally on some standard objects (Like Contact child of Contact) do not have a relationship name.
            //if there is no relationship name, we cannot query on it, so throw an exception.
            if (childRow.getRelationshipName() == 'Tasks') {
                relationship = childRow;
            }
        }
        //explicitly assert object accessibility when creating the subselect
        qf.subselectQuery(relationship).selectField('Id').selectField('Subject').setCondition(' IsDeleted = false ');
        List<SOQLBuilder> queries = qf.getSubselectQueries();
        System.assert(queries != NULL);
        List<Contact> contacts = Database.query(qf.toSOQL());
        System.assert(contacts != NULL && contacts.size() == 1);
        System.assert(contacts[0].Tasks.size() == 1);
        System.assert(contacts[0].Tasks[0].Subject == 'test');
    }

    @IsTest
    static void testAddChildQueriesWithChildRelationshipNoAccessibleCheckFail() {
        Account acct = new Account();
        acct.Name = 'testchildqueriesacct';
        insert acct;

        Contact cont = new Contact();
        cont.FirstName = 'test';
        cont.LastName = 'test';
        cont.AccountId = acct.Id;
        insert cont;

        Task tsk = new Task();
        tsk.WhoId = cont.Id;
        tsk.Subject = 'test';
        tsk.ActivityDate = System.today();
        insert tsk;

        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('name').selectField('Id').setCondition('name like \'%test%\'').addOrdering('CreatedDate', SOQLBuilder.SortOrder.DESCENDING, true);
        Schema.DescribeSObjectResult descResult = Contact.SObjectType.getDescribe();
        //explicitly assert object accessibility when creating the subselect
        Exception e;
        try {
            builder.subselectQuery('Tas').selectField('Id').selectField('Subject').setCondition(' IsDeleted = false ');
        } catch (SOQLBuilder.InvalidSubqueryRelationshipException ex) {
            e = ex;
        }
        System.assertNotEquals(e, NULL);
    }

    @IsTest
    static void testAddChildQueriesSuccess() {
        Account acct = new Account();
        acct.Name = 'testchildqueriesacct';
        insert acct;

        Contact cont = new Contact();
        cont.FirstName = 'test';
        cont.LastName = 'test';
        cont.AccountId = acct.Id;
        insert cont;

        Task tsk = new Task();
        tsk.WhoId = cont.Id;
        tsk.Subject = 'test';
        tsk.ActivityDate = System.today();
        insert tsk;

        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('name').selectField('Id').setCondition( 'name like \'%test%\'' ).addOrdering('CreatedDate', SOQLBuilder.SortOrder.DESCENDING, true);
        Schema.DescribeSObjectResult descResult = Contact.SObjectType.getDescribe();
        //explicitly assert object accessibility when creating the subselect
        builder.subselectQuery('Tasks', true).selectField('Id').selectField('Subject').setCondition('IsDeleted = false');
        List<SOQLBuilder> queries = builder.getSubselectQueries();
        System.assert(queries != NULL);
        List<Contact> contacts = Database.query(builder.toSOQL());
        System.assert(contacts != NULL && contacts.size() == 1);
        System.assert(contacts[0].Tasks.size() == 1);
        System.assert(contacts[0].Tasks[0].Subject == 'test');
    }

    @IsTest
    static void testAddChildQuerySameRelationshipAgainSuccess() {
        Account acct = new Account();
        acct.Name = 'testchildqueriesacct';
        insert acct;

        Contact cont = new Contact();
        cont.FirstName = 'test';
        cont.LastName = 'test';
        cont.AccountId = acct.Id;
        insert cont;

        Task tsk = new Task();
        tsk.WhoId = cont.Id;
        tsk.Subject = 'test';
        tsk.ActivityDate = System.today();
        insert tsk;

        SOQLBuilder qf = new SOQLBuilder(Contact.SObjectType);
        qf.selectField('name');
        qf.selectField('Id');
        qf.setCondition('name like \'%test%\'');
        qf.addOrdering(new SOQLBuilder.Ordering('Contact', 'name', SOQLBuilder.SortOrder.ASCENDING)).addOrdering('CreatedBy.Name', SOQLBuilder.SortOrder.DESCENDING);
        Schema.DescribeSObjectResult descResult = Contact.SObjectType.getDescribe();
        ChildRelationship relationship;
        for (Schema.ChildRelationship childRow : descResult.getChildRelationships()) {
            if (childRow.getRelationshipName() == 'Tasks') {
                relationship = childRow;
            }
        }
        System.assert(qf.getSubselectQueries() == NULL);
        SOQLBuilder childQf = qf.subselectQuery('Tasks');
        childQf.assertIsAccessible();
        childQf.setEnforceFLS(true);
        childQf.selectField('Id');
        SOQLBuilder childQf2 = qf.subselectQuery('Tasks');
        List<SOQLBuilder> queries = qf.getSubselectQueries();

        System.assert(queries != NULL);
        System.assert(queries.size() == 1);
    }

    @IsTest
    static void testAddChildQueriesInvalidChildRelationship() {
        Account acct = new Account();
        acct.Name = 'testchildqueriesacct';
        insert acct;

        Contact cont = new Contact();
        cont.FirstName = 'test';
        cont.LastName = 'test';
        cont.AccountId = acct.Id;
        insert cont;

        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('name');
        builder.selectField('email');
        builder.setCondition('name like \'%test%\'');
        builder.addOrdering(new SOQLBuilder.Ordering('Contact', 'name', SOQLBuilder.SortOrder.ASCENDING)).addOrdering('CreatedDATE', SOQLBuilder.SortOrder.DESCENDING);
        Schema.DescribeSObjectResult descResult = Account.SObjectType.getDescribe();
        Exception e;
        try {
            String invalidType = 'InvalidRelationshipName';
            SOQLBuilder childQf = builder.subselectQuery(invalidType);
            childQf.selectField('Id');
        } catch (SOQLBuilder.InvalidSubqueryRelationshipException ex) {
            e = ex;
        }

        System.assertNotEquals(e, NULL);
    }

    @IsTest
    static void testAddChildQueriesInvalidChildRelationshipTooDeep() {
        Account acct = new Account();
        acct.Name = 'testchildqueriesacct';
        insert acct;

        Contact cont = new Contact();
        cont.FirstName = 'test';
        cont.LastName = 'test';
        cont.AccountId = acct.Id;
        insert cont;

        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.selectField('name');
        builder.selectField('email');
        builder.setCondition('name like \'%test%\'');
        builder.addOrdering(new SOQLBuilder.Ordering('Contact', 'name', SOQLBuilder.SortOrder.ASCENDING) ).addOrdering('CreatedDATE', SOQLBuilder.SortOrder.DESCENDING);
        Schema.DescribeSObjectResult descResult = Contact.SObjectType.getDescribe();

        SOQLBuilder childQf = builder.subselectQuery('Tasks');
        childQf.selectField('Id');
        childQf.selectField('Subject');
        Exception e;
        try {
            SOQLBuilder subChildQf = childQf.subselectQuery('Tasks');
        } catch (SOQLBuilder.InvalidSubqueryRelationshipException ex) {
            e = ex;
        }
        System.assertNotEquals(e, NULL);
    }

    @IsTest
    static void testCheckFieldObjectReadSortSuccess() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.assertIsAccessible()
            .setEnforceFLS(true)
            .selectField('createdby.name')
            .selectField(Contact.LastModifiedById)
            .selectFields(new List<SObjectField>{Contact.LastModifiedDate})
            .setEnforceFLS(false)
            .selectField(Contact.LastName)
            .selectFields(new List<SObjectField>{Contact.Id})
            .setCondition('name like \'%test%\'')
            .setEnforceFLS(true)
            .selectFields(new Set<SObjectField>{Contact.FirstName})
            .addOrdering(new SOQLBuilder.Ordering('Contact', 'name', SOQLBuilder.SortOrder.ASCENDING))
            .addOrdering(Contact.LastModifiedDate,SOQLBuilder.SortOrder.DESCENDING)
            .addOrdering(Contact.CreatedDate,SOQLBuilder.SortOrder.DESCENDING, true);

        Set<String> selectedFields = new Set<String>();
        for (SOQLBuilder.QueryField qField : builder.getSelectedFields()) {
            selectedFields.add(qField.toString());
        }

        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Contact', 'name', SOQLBuilder.SortOrder.ASCENDING);
        System.assertEquals('Name', ordering.getFields()[0].getDescribe().getName());

        System.assertEquals(
            new Set<String>{
                'CreatedBy.Name',
                'LastModifiedById',
                'LastModifiedDate',
                'LastName',
                'Id',
                'FirstName'
            },
            selectedFields
        );

        System.assert(builder.toSOQL().containsIgnoreCase('NULLS LAST'));
    }

    @IsTest
    static void testCheckObjectReadFail() {
        User usr = createTestUserNoAccess();
        if (usr != NULL) {
            System.runAs(usr) {
                //create a query factory object for Account.
                SOQLBuilder qf = new SOQLBuilder(Account.SObjectType);
                Boolean excThrown = false;
                try {
                    //check to see if this record is accessible, it isn't.
                    qf.assertIsAccessible();
                } catch (SFDCSecurityUtils.CrudException e) {
                    excThrown = true;
                }
                System.assert(excThrown);
            }
        }
    }

    @IsTest
    static void testCheckFieldReadFail() {
        User usr = createTestUserNoAccess();
        if (usr != NULL) {
            System.runAs(usr) {
                //create a query factory object for Account.
                SOQLBuilder builder = new SOQLBuilder(Account.SObjectType);
                Boolean excThrown = false;
                try {
                    //set field to enforce FLS, then try to add a field.
                    builder.setEnforceFLS(true);
                    builder.selectField('Name');
                } catch (SFDCSecurityUtils.FlsException e) {
                    excThrown = true;
                }
                System.assertNotEquals(true, excThrown);
                System.assertEquals(true, SFDCSecurityUtils.flsInspector.getFlsInspectionResults()[0].inspectionFailed);

            }
        }
    }

    @IsTest
    static void testQueryWithNoFields() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType);
        builder.assertIsAccessible().setEnforceFLS(true).setCondition('name like \'%test%\'').addOrdering('CreatedDate', SOQLBuilder.SortOrder.DESCENDING);
        String query = builder.toSOQL();
        System.assert(query.containsIgnoreCase('SELECT Id FROM Contact'), 'Expected \'SELECT Id FROM Contact\' in the SOQL, found: ' + query);
    }

    @IsTest
    static void testDeepCloneBasicNoChanges() {
        SOQLBuilder qf = new SOQLBuilder(Contact.SObjectType)
            .setLimit(10)
            .setCondition('id=12345')
            .selectField('Description')
            .addOrdering(new SOQLBuilder.Ordering('Contact', 'name', SOQLBuilder.SortOrder.ASCENDING) )
            .addOrdering( new SOQLBuilder.Ordering('Contact', 'CreatedDATE', SOQLBuilder.SortOrder.DESCENDING))
            .setEnforceFLS(true);

        SOQLBuilder qf2 = qf.deepClone();

        System.assertEquals(qf2, qf);

        System.assertEquals(qf.getLimit(), qf2.getLimit());
        System.assertEquals(qf.getCondition(), qf2.getCondition());
        System.assertEquals(qf.toSOQL(), qf2.toSOQL());
        System.assertEquals(qf.getOrderings(), qf2.getOrderings());
    }

    @IsTest
    static void testDeepCloneSubqueryNoChanges() {
        SOQLBuilder builder = new SOQLBuilder(Account.SObjectType)
            .setLimit(10)
            .setCondition('id=12345')
            .selectField('Description')
            .addOrdering(new SOQLBuilder.Ordering('Account', 'Name', SOQLBuilder.SortOrder.ASCENDING) )
            .addOrdering(new SOQLBuilder.Ordering('Account', 'Description', SOQLBuilder.SortOrder.DESCENDING))
            .setEnforceFLS(true);

        builder.subselectQuery('Contacts', true);

        SOQLBuilder qf2 = builder.deepClone();

        System.assertEquals(builder, qf2);

        System.assertEquals(builder.getLimit(), qf2.getLimit());
        System.assertEquals(builder.getCondition(), qf2.getCondition());
        System.assertEquals(builder.toSOQL(), qf2.toSOQL());
        System.assertEquals(builder.getOrderings(), qf2.getOrderings());
        System.assertEquals(builder.getSubselectQueries(), qf2.getSubselectQueries());
    }

    @IsTest
    static void testDeepCloneBasic() {
        SOQLBuilder builder = new SOQLBuilder(Contact.SObjectType)
            .setLimit(10)
            .setCondition('id=12345')
            .selectField('Description')
            .addOrdering(new SOQLBuilder.Ordering('Contact', 'name', SOQLBuilder.SortOrder.ASCENDING))
            .addOrdering(new SOQLBuilder.Ordering('Contact', 'CreatedDATE', SOQLBuilder.SortOrder.DESCENDING))
            .setEnforceFLS(true);


        SOQLBuilder builder2 = builder.deepClone()
            .setLimit(200)
            .setCondition('id=54321')
            .selectField('Fax')
            .addOrdering(new SOQLBuilder.Ordering('Contact', 'Fax', SOQLBuilder.SortOrder.ASCENDING))
            .setEnforceFLS(false);

        builder2.getOrderings().remove(0);

        System.assertEquals(10, builder.getLimit());
        System.assertEquals(200, builder2.getLimit());

        System.assertEquals('id=12345', builder.getCondition());
        System.assertEquals('id=54321', builder2.getCondition());

        String query = builder.toSOQL();
        String query2 = builder2.toSOQL();

        System.assert(query.containsIgnoreCase('Fax') == false);
        System.assert(query.containsIgnoreCase('Description'));
        System.assert(query2.containsIgnoreCase('Description'));
        System.assert(query2.containsIgnoreCase('Fax'));

        System.assertEquals(2, builder.getOrderings().size());
        System.assertEquals('Name', builder.getOrderings()[0].getFields()[0].getDescribe().getName());
        System.assertEquals(SOQLBuilder.SortOrder.DESCENDING, builder.getOrderings()[1].getDirection());

        System.assertEquals(2, builder2.getOrderings().size());
        System.assertEquals('Fax', builder2.getOrderings()[1].getFields()[0].getDescribe().getName());
        System.assertEquals(SOQLBuilder.SortOrder.ASCENDING, builder2.getOrderings()[1].getDirection());
    }

    @IsTest
    static void testDeepCloneSubquery() {
        SOQLBuilder builder = new SOQLBuilder(Account.SObjectType);
        builder.subselectQuery('Contacts', true);

        SOQLBuilder builder2 = builder.deepClone();
        builder2.subselectQuery('Opportunities', true);

        List<SOQLBuilder> subqueries = builder.getSubselectQueries();
        List<SOQLBuilder> subqueries2 = builder2.getSubselectQueries();

        SOQLBuilder subquery2_0 = subqueries2.get(0);

        subquery2_0.addOrdering(new SOQLBuilder.Ordering('Contact', 'Name', SOQLBuilder.SortOrder.ASCENDING));

        System.assert(subqueries.size() == 1);
        System.assert(subqueries2.size() == 2);

        System.assert(builder.getSubselectQueries().get(0).getOrderings().size() == 0);
        System.assert(builder2.getSubselectQueries().get(0).getOrderings().size() == 1);
    }

    @IsTest
    static void testSoqlUnsortedSelectFields() {
        //Given
        SOQLBuilder builder = new SOQLBuilder(User.SObjectType);
        builder.selectFields(new List<String>{
            'Id',
            'FirstName',
            'LastName',
            'CreatedBy.Name',
            'CreatedBy.Manager',
            'LastModifiedBy.Email'
        });

        builder.setSortSelectFields(false);

        String orderedQuery =
            'SELECT FirstName, Id, LastName, ' //less joins come first, alphabetically
                + 'CreatedBy.ManagerId, CreatedBy.Name, LastModifiedBy.Email ' //alphabetical on the same number of joins'
                + 'FROM User';

        //When
        String actualSoql = builder.toSOQL();

        //Then
        System.assertNotEquals(orderedQuery, actualSoql);
    }

    public static User createTestUserNoAccess() {
        User usr;
        try {
            //look for a profile that does not have access to the Account object
            PermissionSet ps = [
                SELECT Profile.Id, Profile.Name
                FROM PermissionSet
                WHERE IsOwnedByProfile = true
                AND Profile.UserType = 'Standard'
                AND Id NOT IN (SELECT ParentId FROM ObjectPermissions WHERE SObjectType = 'Account' AND PermissionsRead = true)
                LIMIT 1
            ];

            if (ps != NULL) {
                //create a user with the profile found that doesn't have access to the Account object
                usr = new User(
                    FirstName = 'testUsrF',
                    LastName = 'testUsrL',
                    Alias = 'tstUsr',
                    Email = 'testy.test@test.com',
                    UserName = 'test' + Math.random().format() + 'user99@test.com',
                    EmailEncodingKey = 'ISO-8859-1',
                    LanguageLocaleKey = 'en_US',
                    TimeZoneSidKey = 'America/Los_Angeles',
                    LocaleSidKey = 'en_US',
                    ProfileId = ps.Profile.Id,
                    IsActive = true
                );
                insert usr;
            }
        } catch (Exception e) {
            //do nothing, just return NULL User because this test case won't work in this org.
            return NULL;
        }
        return usr;
    }

    @IsTest
    public static void testStripInaccessibleCRUDAndFlsWithoutAccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[2]) {
            List<String> fields = new List<String> {
                'Id',
                'Name',
                'Status__c',
                'Balance__c'
            };

            SOQLBuilder queryBuilder = new SOQLBuilder(Billing__c.SObjectType);
            queryBuilder
                .setStripInaccessible(AccessType.READABLE)
                .selectFields(fields);
            List<Billing__c> result = (List<Billing__c>) queryBuilder.getAccessDecisionResult(Database.query(queryBuilder.toSOQL()));

            System.assertEquals(new List<SObject>(), result);
        }
    }

    @IsTest
    public static void testStripInaccessibleCRUDAndFlsWithAccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        TestDataSuite.assignAdminPermissionSet(testData.users[2].Id, false);
        System.runAs(testData.users[2]) {
            List<String> fields = new List<String> {
                'Id',
                'Name',
                'Status__c',
                'Balance__c'
            };

            SOQLBuilder queryBuilder = new SOQLBuilder(Billing__c.SObjectType);
            queryBuilder
                .setStripInaccessible(AccessType.READABLE)
                .selectFields(fields);
            List<Billing__c> result = (List<Billing__c>) queryBuilder.getAccessDecisionResult(Database.query(queryBuilder.toSOQL()));
            List<Billing__c> expectedResult = [SELECT Id, Name, Status__c, Balance__c FROM Billing__c];
            System.assertEquals(expectedResult, result);
        }
    }

    @IsTest
    public static void testStripInaccessibleFlsDefault() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        TestDataSuite.assignAdminPermissionSet(testData.users[2].Id, false);
        System.runAs(testData.users[2]) {
            List<String> fields = new List<String> {
                'Id',
                'Name',
                'Status__c',
                'Balance__c'
            };

            SOQLBuilder queryBuilder = new SOQLBuilder(Billing__c.SObjectType);
            queryBuilder
                .setStripInaccessible()
                .selectFields(fields);
            List<Billing__c> result = (List<Billing__c>) queryBuilder.getAccessDecisionResult(Database.query(queryBuilder.toSOQL()));
            List<Billing__c> expectedResult = [SELECT Id, Name, Status__c, Balance__c FROM Billing__c];
            System.assertEquals(expectedResult, result);
        }
    }

    @IsTest
    public static void testStripInaccessibleFlsEditable() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        TestDataSuite.assignAdminPermissionSet(testData.users[2].Id, false);
        System.runAs(testData.users[2]) {
            List<String> fields = new List<String> {
                'Id',
                'Name',
                'Status__c',
                'Balance__c'
            };

            SOQLBuilder queryBuilder = new SOQLBuilder(Billing__c.SObjectType);
            queryBuilder
                .setStripInaccessible(AccessType.CREATABLE)
                .selectFields(fields);
            List<Billing__c> result = (List<Billing__c>) queryBuilder.getAccessDecisionResult(Database.query(queryBuilder.toSOQL()));
            List<Billing__c> expectedResult = [SELECT Id, Status__c FROM Billing__c];
            System.assertEquals(expectedResult, result);
        }
    }

}