public with sharing class Milestone1_GoogleChartUtility {
	
	Map<String, List<Milestone1_Milestone__c> >  stepsMap = new Map<String, List<Milestone1_Milestone__c> >();
	
	/**
	* Get all list of Projects in order to process it and return again
	* @param projs
	* @return projs
	* @author Sebastian Muñoz
	*/
	public List<Milestone1_Project__c> getGoogleGanntList( List<Milestone1_Project__c> projs ) {
		List<Id> projIds = new List<Id>();
		
		for( Milestone1_Project__c p : projs ) { projIds.add( p.Id ); }
		
		for( Milestone1_Project__c p : projs ) {
			
			List<Milestone1_Milestone__c> auxList = new List<Milestone1_Milestone__c> ();
			
			for( Milestone1_Milestone__c st : this.getProjMilestones( projIds ) ) {
				if( p.Id == st.Project__c ) { 
					System.debug('\n\n\n '+ p.Id +' :'+ st +'\n\n\n' );
					auxList.add( st ); 
				}
			}
			
			if( !auxList.isEmpty() ) { this.stepsMap.put( p.Id, auxList );	}
			
			this.getGoogleGannt( p );
			
		}
		
		return projs;
	}
	
	
	/**
	* Get all list of Milestones
	* @param projs
	* @return projMilestones
	* @author Sebastian Muñoz
	*/
	private List<Milestone1_Milestone__c> getProjMilestones( List<Id> projIds ){
		return [SELECT	m.Name, m.Kickoff__c, m.Id, m.Deadline__c, m.Duration__c, m.Project_Kickoff_Offset__c, m.Complete__c, Project__c
				FROM 	Milestone1_Milestone__c m 
				WHERE 	m.Project__c IN: projIds
				AND 	m.Parent_Milestone__c = null 
				AND	 	m.Kickoff__c != null 
				AND 	m.Deadline__c != null  
				ORDER 	BY m.kickoff__c ];
	}
	
	
	
	
	public void getGoogleGannt( Milestone1_Project__c project ) {
		if ( project.Deadline__c != null && project.Kickoff__c != null  && project.Kickoff__c <= project.Deadline__c ) {
	

			String ret = 'http://chart.apis.google.com/chart?cht=bhs&chs=800x200';
	
			
			String seriesColor 			= '';
			String seriesOffset 		= '';
			String seriesDuration 		='';
			String seriesName 			= '';
			
			List<Integer> offset 		= new List<Integer>();
			List<Integer> complete 		= new List<Integer>();
			List<Integer> inprogress 	= new List<Integer>();
			List<Integer> late 			= new List<Integer>();
			List<Integer> upcoming 		= new List<Integer>();
			
			List<Milestone1_Milestone__c> mList = ( this.stepsMap.get( project.Id ) != null ) ? this.stepsMap.get( project.Id ) : new List<Milestone1_Milestone__c>();
			
			for ( Milestone1_Milestone__c current : mList ) {
				
				//Colors based on status
				if (seriesColor.length() > 0) { seriesColor += ',';	}
					
					//data series
					//0: lead time (won't display)
					//1: complete
					//2: in progress
					//3: late
					//4: upcoming
					//every data series has steps.size() elements
					
					offset.add( current.Project_Kickoff_Offset__c.round().intValue() );
					
					if ( current.Complete__c ) {
						complete.add(current.Duration__c.round().intValue());
						inprogress.add(0);
						late.add(0);
						upcoming.add(0);
					} 
					else if ( current.Deadline__c.daysBetween(Date.today()) > 0 ) {
						complete.add(0);
						inprogress.add(0);
						late.add(current.Duration__c.round().intValue());
						upcoming.add(0);
					} 
					else if ( current.Kickoff__c.daysBetween(Date.today()) < 0 ) {
						complete.add(0);
						inprogress.add(0);
						late.add(0);
						upcoming.add(current.Duration__c.round().intValue());				
					} 
					else {
						complete.add(0);
						inprogress.add(current.Duration__c.round().intValue());
						late.add(0);
						upcoming.add(0);
					}
					
					if ( seriesName.length() > 0 ) { seriesName = '|' + seriesName; }
					
					String currentName = current.Name;
					
					seriesName = EncodingUtil.urlEncode(currentName,'UTF-8') + seriesName;
				}
			
			//build date series
			Date currentDate = project.Kickoff__c;
			Long increment = ( project.Duration__c /10 ).round();
			String dateSeries = '';
			
			while ( currentDate <= project.Deadline__c && increment.intValue() > 0 ) {
				
				if (dateSeries.length() > 0) 
					dateSeries += '|';
				
				Datetime currentDatetime = Datetime.newInstance(currentDate.year(), currentDate.month(), currentDate.day());
				
				dateSeries += currentDatetime.format('d+MMM');
					
				currentDate = currentDate.addDays( increment.intValue() );
			}
	
			//add colors -- note that the first color is black - 000000 - with 0% opacity - 00 8 chars instead of the usual 6.
			ret += '&chco=00000000,000000,2299bb,ee3322,666666';	
			//add the key -- note the first key is blank
			ret += '&chdl=|Complete|In+Progress|Late|Upcoming';	
			// legend position top if #milestones < 3
			ret += mList.size() < 3 ? '&chdlp=t' : '';	
			//add the scale
			ret += '&chds=0,' + project.Duration__c;
			//add line one of data
			ret += '&chd=t:';		
			
			ret += getSeries(offset) + '|' + 
			getSeries(complete) + '|' + 
			getSeries(inprogress) + '|' + 
			getSeries(late) + '|' + 
			getSeries(upcoming);
			
			
			ret += '&chxt=x,y&chxl=';
			ret += '0:|' + dateSeries;
			ret += '|1:|' + seriesName;
			
			//add some vertical dotted lines
			Decimal daysAsPercent = 100 / project.Duration__c;
			ret += '&chg=' + daysAsPercent.format() + ',0';
			
			//where are we today?  add highlighting
			//&chm=r,99ccff44,0,0,0.29
			//days between today and kickoff
			Integer daysFromKickoff = project.Kickoff__c.daysBetween(Date.today());
			if (daysFromKickoff > 0) {
				Decimal percentPerDay = 100 / project.Duration__c;
				Decimal currentPercent = percentPerDay * daysFromKickoff / 100;
				currentPercent = currentPercent.setScale(2);
				ret += '&chm=r,99ccff44,0,0,' + currentPercent;
			}
			
			//chart title
			ret += '&chtt=' + EncodingUtil.urlencode(project.Name + ' ('+Datetime.now().format('d-MMM-yyyy')+')', 'UTF-8');
			
			project.GoogleGanntUrl__c =  ret;
		}
		else{
			project.GoogleGanntUrl__c =  '';
		}
	}

	public String getSeries(List<Integer> target) {
		String ret = '';
		
		for (Integer current : target) {
			if (ret.length() > 0) {
				ret += ',';
			}
			ret += current.format();
		}
		return ret;
	}
	

	static TestMethod void simpleTest() {
		
		Milestone1_Project__c p = Milestone1_Test_Utility.sampleProjectActive('Test project 1');
		insert p;
		p = [Select m.Status_TasksOpenComplete__c, m.Status_TasksOpenBlockedLate__c, 
		m.Status_BudgetMiletoneEstimate__c, m.Status_BudgetExpenseSummary__c, m.Name, m.Id, m.Deadline__c, m.Kickoff__c, 
		m.Duration__c, m.GoogleGanntUrl__c
		From Milestone1_Project__c m where m.id = :p.id];
		
		//in progress
		Milestone1_Milestone__c ms1 = Milestone1_Test_Utility.sampleMilestone(p);
		upsert ms1;
		
		//complete
		Milestone1_Milestone__c ms2 = Milestone1_Test_Utility.sampleMilestone(p);
		ms2.Complete__c = true;
		upsert ms2;
		//late
		Milestone1_Milestone__c ms3 = Milestone1_Test_Utility.sampleMilestone(p);
		ms3.Deadline__c = Date.today().addDays(-1);
		upsert ms3;
		//future
		Milestone1_Milestone__c ms4 = Milestone1_Test_Utility.sampleMilestone(p);
		ms4.Deadline__c = Date.today().addDays(1);
		upsert ms4;
		

		
		
		Milestone1_Task__c t = Milestone1_Test_Utility.sampleTask(ms1);
		upsert t;
		
		Milestone1_GoogleChartUtility googleChartUtility = new Milestone1_GoogleChartUtility();
		
		List<Milestone1_Project__c> prj = new List<Milestone1_Project__c>{ p };
		googleChartUtility.getGoogleGanntList( prj );

		System.assert( !prj.isEmpty() );
		

		
	}
}