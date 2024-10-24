@IsTest
public class ProjectFromOpportunityTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testNoSelectedTemplateCategoryProjectError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opportunity';
            opp.CloseDate = System.today();
            opp.StageName = 'Closed Won';
            insert opp;

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            ProjectFromOpportunity pfm = new ProjectFromOpportunity(controller);
            pfm.createOrAddProject();

            System.assertEquals(1, ApexPages.getMessages().size());
            System.assertEquals(ApexPages.SEVERITY.ERROR, ApexPages.getMessages().get(0).getSeverity());
        }

    }

    @IsTest
    public static void testCreateProject() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.projects[1].Template_Project__c = true;
            testData.projects[1].Status__c = 'Active';
            update testData.projects[1];

            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opportunity';
            opp.CloseDate = System.today();
            opp.StageName = 'Closed Won';
            insert opp;

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            ProjectFromOpportunity pfm = new ProjectFromOpportunity(controller);
            pfm.selectedTemplateProject = testData.projects[1].Id;
            pfm.createOrAddProject();
            PageReference refPage = pfm.saveMapping();

            System.assertEquals(opp.Name, [SELECT Id, Name FROM Project__c WHERE Id = :pfm.projectId].Name);
            System.assertEquals(true, pfm.isWillClone);
            System.assertEquals(refPage.getUrl(), new PageReference('/' + pfm.projectId).getUrl());
        }

    }

    @IsTest
    public static void testCreateProjectTruncateName() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.projects[1].Template_Project__c = true;
            testData.projects[1].Status__c = 'Active';
            update testData.projects[1];

            Opportunity opp = new Opportunity();
            opp.Name = 'New Oppsdgdfgsdfgsdfgsdffgs 34qgerfegsherjfgs bnserhnsndfshdfhdf nshrfdhserhrehbfdbsrhrebsf nstfhsrehrehrsehbzdfheragbae';
            opp.CloseDate = System.today();
            opp.StageName = 'Closed Won';
            insert opp;

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            ProjectFromOpportunity pfm = new ProjectFromOpportunity(controller);
            pfm.selectedTemplateProject = testData.projects[1].Id;
            pfm.createOrAddProject();
            PageReference refPage = pfm.saveMapping();

            System.assertEquals(opp.Name.substring(0,79), [SELECT Id, Name FROM Project__c WHERE Id = :pfm.projectId].Name);
            System.assertEquals(true, pfm.isWillClone);
            System.assertEquals(refPage.getUrl(), new PageReference('/' + pfm.projectId).getUrl());
        }

    }

    @IsTest
    public static void testAddProject() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.projects[1].Template_Project__c = true;
            testData.projects[1].Status__c = 'Active';
            update testData.projects[1];

            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opportunity';
            opp.CloseDate = System.today();
            opp.StageName = 'Closed Won';
            insert opp;

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            ProjectFromOpportunity pfm = new ProjectFromOpportunity(controller);
            pfm.emptyProduct.Project__c = testData.projects[1].Id;
            pfm.createOrAddProject();
            PageReference refPage = pfm.saveMapping();

            System.assertEquals(false, pfm.isWillClone);
            System.assertEquals(new PageReference('/' + testData.projects[1].Id).getUrl(), refPage.getUrl());
        }

    }

    @IsTest
    public static void testProjectDoesExists() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opportunity';
            opp.CloseDate = System.today();
            opp.StageName = 'Closed Won';
            insert opp;

            testData.projects[0].Opportunity__c = opp.Id;
            update testData.projects[0];

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            ProjectFromOpportunity pfm = new ProjectFromOpportunity(controller);

            System.assertEquals(1, ApexPages.getMessages().size());
            System.assertEquals(ApexPages.SEVERITY.WARNING, ApexPages.getMessages().get(0).getSeverity());
        }

    }

    @IsTest
    public static void testProjectMappingWithTasks() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.projects[1].Template_Project__c = true;
            testData.projects[1].Status__c = 'Active';
            update testData.projects[1];

            Project_Task__c tsk = new Project_Task__c(
                Name = 'Test task',
                Project__c = testData.projects[1].Id,
                Status__c = 'Active'
            );
            insert tsk;

            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opportunity';
            opp.CloseDate = System.today();
            opp.StageName = 'Closed Won';
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(new PricebookEntry(Product2Id = product.Id, PriceBook2Id = pricebookId, UnitPrice = 4000, isActive = true, UseStandardPrice = false));
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(new OpportunityLineItem(PriceBookEntryId = pbe.Id, OpportunityId = opp.Id, Quantity = 2, UnitPrice = 4000));
            }

            insert oliList;

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            ProjectFromOpportunity pfm = new ProjectFromOpportunity(controller);
            pfm.selectedTemplateProject = testData.projects[1].Id;
            pfm.createOrAddProject();

            System.assertEquals(true, pfm.isShowProductsTable);

            List<Project_Task__c> cloneTasks = [SELECT Id, Name FROM Project_Task__c WHERE Project__c = :pfm.projectId];
            System.assert(cloneTasks.size() > 0);
            List<String> taskIds = new List<String> {
                '',
                ProjectFromOpportunity.SELECT_OPTION_CREATE_VALUE,
                cloneTasks.get(0).Id,
                ProjectFromOpportunity.SELECT_OPTION_CREATE_VALUE
            };
            for (Integer i = 0; i < pfm.productsWrapper.products.size(); i++) {
                pfm.productsWrapper.products.get(i).task = taskIds.get(i);
            }

            PageReference result = pfm.saveMapping();

            System.assertEquals('/' + pfm.projectId, result.getUrl());
        }

    }

    @IsTest
    public static void testProjectNoSelectCreateOrAdd() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.projects[1].Template_Project__c = true;
            testData.projects[1].Status__c = 'Active';
            update testData.projects[1];

            Project_Task__c tsk = new Project_Task__c(
                Name = 'Test task',
                Project__c = testData.projects[1].Id,
                Status__c = 'Active'
            );
            insert tsk;

            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opportunity';
            opp.CloseDate = System.today();
            opp.StageName = 'Closed Won';
            insert opp;

            Id pricebookId = Test.getStandardPriceBookId();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            Product2[] productList = new List<Product2>();

            for (Integer i = 0; i < 4; i++) {
                productList.add(new Product2(Name = 'Test ' + i, Revenue_GL_Account__c = testData.glAccounts[16].Id));
            }

            insert productList;

            for (Product2 product : productList) {
                pbeList.add(new PricebookEntry(Product2Id = product.Id, PriceBook2Id = pricebookId, UnitPrice = 4000, isActive = true, UseStandardPrice = false));
            }

            insert pbeList;

            for (PricebookEntry pbe : pbeList) {
                oliList.add(new OpportunityLineItem(PriceBookEntryId = pbe.Id, OpportunityId = opp.Id, Quantity = 2, UnitPrice = 4000));
            }

            insert oliList;

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            ProjectFromOpportunity pfm = new ProjectFromOpportunity(controller);
            pfm.createOrAddProject();

            System.assertEquals(1, ApexPages.getMessages().size());
            System.assertEquals(ApexPages.SEVERITY.ERROR, ApexPages.getMessages().get(0).getSeverity());
        }

    }

    @IsTest
    public static void OppProductsWrapperWrongProjectIdError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Opportunity';
            opp.CloseDate = System.today();
            opp.StageName = 'Closed Won';
            insert opp;

            ApexPages.StandardController controller = new ApexPages.StandardController(opp);
            ProjectFromOpportunity pfm = new ProjectFromOpportunity(controller);

            ProjectFromOpportunity.OppProductsWrapper productsWrapper = new ProjectFromOpportunity.OppProductsWrapper(opp);

            Exception ex;
            try {
                Id result = productsWrapper.saveMapping(opp.Id, opp, true, NULL);
            }
            catch (Exception exeption) {
                ex = exeption;
            }

            System.assertNotEquals(NULL, ex);
        }

    }
}