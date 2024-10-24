@IsTest
public with sharing class SObjectSelectorTest {
    
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    @TestSetup
	static void testSetup(){
		TestDataSuite.getInstance(true);
	}

    @IsTest
    static void testGetSObjectType(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            SObjectSelector selector = new TestBillingSelector();
            Assert.areEqual(Billing__c.sObjectType, selector.getSObjectType());
        }
    }

    @IsTest
    static void testGetSObjectName(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            SObjectSelector selector = new TestBillingSelector();
            Assert.areEqual(Billing__c.sObjectType.getDescribe().getName(), selector.getSObjectName());
        }
    }

    @IsTest
    static void testGetSObjectFields(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            SObjectSelector selector = new TestBillingSelector();
            List<Schema.SObjectField> fields = selector.getSObjectFields();
            Assert.areEqual(2, fields.size());
            Assert.isTrue(fields.contains(Billing__c.Name));
            Assert.isTrue(fields.contains(Billing__c.Id));
        }
    }

    @IsTest
    static void testGetSObjectFieldNames(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            SObjectSelector selector = new TestBillingSelector();
            Set<String> fields = selector.getSObjectFieldNames();
            Assert.areEqual(2, fields.size());
            Assert.isTrue(fields.contains(Account.Name.getDescribe().getName()));
            Assert.isTrue(fields.contains(Account.Id.getDescribe().getName()));
        }
    }

    @IsTest
    static void testIncludeFieldSets(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            SObjectSelector selector = new TestBillingSelector();
            
            List<Schema.FieldSet> fieldSets = new List<Schema.FieldSet>{
                Billing__c.SObjectType.getDescribe().fieldsets.getMap().get(PACKAGE_QUALIFIER + 'MassAddEditRows')
            };
            selector.includeFieldSets(fieldSets);

            Set<Id> ids = new Set<Id>{
                testData.billings[0].Id
            };

            List<SObject> results = selector.selectSObjectsById(ids);
            
            Assert.areEqual(1, results.size());
            try {
                for(Schema.FieldSetMember member : fieldSets[0].getFields()){
                    results[0].get(member.getFieldPath());
                }
            } catch(SObjectException e) {
                Assert.fail('Field not found: ' + e.getMessage());
            }
        }
    }

    @IsTest
    static void testSelectSObjectsById(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            SObjectSelector selector = new TestBillingSelector();
            Set<Id> ids = new Set<Id>{
                testData.billings[0].Id,
                testData.billings[1].Id
            };
            List<SObject> results = selector.selectSObjectsById(ids);
            Assert.areEqual(ids.size(), results.size());
            Assert.isTrue(ids.contains(results[0].Id));
            Assert.isTrue(ids.contains(results[1].Id));
        }
    }

    @IsTest
    static void testQueryLocatorById(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            SObjectSelector selector = new TestBillingSelector();
            Set<Id> ids = new Set<Id>{
                testData.billings[0].Id,
                testData.billings[1].Id
            };
            Database.QueryLocator locator = selector.queryLocatorById(ids);
            Database.QueryLocatorIterator itr = locator.iterator();
            List<SObject> results = new List<SObject>();
            while(itr.hasNext()) {
                results.add(itr.next());
                if (results.size() > 5) {
                    break;
                }
            }
            Assert.areEqual(ids.size(), results.size());
            Assert.isTrue(ids.contains(results[0].Id));
            Assert.isTrue(ids.contains(results[1].Id));
        }
    }

    @IsTest
    static void testConstructors(){
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            SObjectSelector restrictiveSelector = new TestBillingSelector();
            Assert.areEqual(System.AccessLevel.USER_MODE, restrictiveSelector.accessLevel, 'Expected the most restrictive access level.'); 
            Assert.areEqual(SObjectSelector.SharingMode.WITH_SHARING, restrictiveSelector.sharingType, 'Expected the most restrictive sharing mode.');   
            
            SObjectSelector permissiveSelector = new TestBillingSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            Assert.areEqual(System.AccessLevel.SYSTEM_MODE, permissiveSelector.accessLevel, 'Expected the most permissive access level.'); 
            Assert.areEqual(SObjectSelector.SharingMode.WITHOUT_SHARING, permissiveSelector.sharingType, 'Expected the most permissive sharing mode.');   
        }
    }

    @IsTest
    static void testAccessLevelUser(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        User stdUser;
        System.runAs(testData.users.get(1)) {
            stdUser = createStdUser();   
            insert stdUser;
        }

        System.runAs(stdUser) {
            SObjectSelector selector = new TestBillingSelector(System.AccessLevel.USER_MODE, SObjectSelector.SharingMode.WITH_SHARING);
            try {
                selector.selectSObjectsById(new Set<Id>{testData.billings[0].Id});
                Assert.fail('Expected an exception to be thrown. User should not have access to the Billing__c object.');
            } catch (SFDCSecurityUtils.CrudException e) {
                // we expect this exception
            }
        }
    }

    @IsTest
    static void testAccessLevelSys(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        User stdUser;
        System.runAs(testData.users.get(1)) {
            stdUser = createStdUser();   
            insert stdUser;
        }

        System.runAs(stdUser) {
            SObjectSelector selector = new TestBillingSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<SObject> objs = selector.selectSObjectsById(new Set<Id>{testData.billings[0].Id});
            Assert.isNotNull(objs);
            Assert.areEqual(1, objs.size());
        }
    }

    private with sharing class TestBillingSelector extends SObjectSelector {
		public TestBillingSelector() {
			super();
		}
		public TestBillingSelector(System.AccessLevel accessLevel, SharingMode sharingType) {
			super(accessLevel, sharingType);
		}
        public override Schema.SObjectType getSObjectType() {
			return Billing__c.sObjectType;
		}
		public override List<Schema.SObjectField> getSObjectFields() {
			return new List<Schema.SObjectField> {
				Billing__c.Name,
				Billing__c.Id
			};
		}
	}

    private static User createStdUser(){
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
        return new User(
            Alias = 'stdUsr',
            Email = 'standarduser@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'acctseed.test.standarduser@as.com'
        );
    }

}