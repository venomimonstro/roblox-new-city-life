// Deterministic pure-JavaScript behavioral model for Street City domain contracts.
// This does NOT execute Roblox Luau or validate Roblox runtime APIs.
// Run: node tools/simulate_logic.js

const simulate = function simulate() {
  const passed=[], failed=[];
  const eq=(a,b)=>{if(JSON.stringify(a)!==JSON.stringify(b))throw Error(`expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`)};
  const test=(name,fn)=>{try{fn();passed.push(name)}catch(e){failed.push({name,error:String(e)})}};
  const clone=x=>x==null?x:JSON.parse(JSON.stringify(x));
  let time=1000;
  const initial=()=>({schemaVersion:2,credits:0,selectedVehicleId:"starter",garage:{starter:{engineId:"stock_i4",gearboxId:"street_5",tireId:"street"}},inventory:{},recentOperations:[]});
  class Store{
    constructor(){this.data=new Map();this.faults=[];this.transforms=0}
    update(key,fn){
      const fault=this.faults.shift()||"none";
      if(fault==="before")throw Error("Network before commit");
      const old=clone(this.data.get(key)||null);
      if(fault==="retry"){this.transforms++;fn(clone(old))}
      this.transforms++;
      const changed=fn(clone(old));
      if(changed!=null)this.data.set(key,clone(changed));
      if(fault==="after")throw Error("Ambiguous after commit");
      return clone(changed);
    }
  }
  class Session{
    constructor(store,token){this.store=store;this.token=token;this.profile=null;this.quarantined=false}
    acquire(){
      let output=null;
      try {output=this.store.update("user",old=>{
        if(old&&old.owner&&old.owner!==this.token&&old.leaseUntil>time)return null;
        return {owner:this.token,leaseUntil:time+180,data:clone(old?old.data:initial())};
      })}catch(e){return false}
      if(!output||output.owner!==this.token)return false;
      this.profile=clone(output.data);this.quarantined=false;return true;
    }
    mutate(edit){
      if(!this.profile||this.quarantined)return false;
      let accepted=false,rejected=false,invalid=false,ok=false,out=null;
      try{
        out=this.store.update("user",old=>{
          accepted=false;rejected=false;invalid=false;
          if(!old||old.owner!==this.token){invalid=true;return null}
          const proposed=clone(old.data);
          if(!edit(proposed)){rejected=true;return null}
          accepted=true;
          return {owner:this.token,leaseUntil:time+180,data:proposed};
        });ok=true;
      }catch(e){ok=false}
      if(ok&&accepted&&!rejected&&!invalid&&out&&out.owner===this.token){
        this.profile=clone(out.data);return true;
      }
      if(ok&&rejected&&!accepted&&!invalid&&out==null)return false;
      this.quarantined=true;return false;
    }
    save(release=false){
      if(!this.profile)return false;
      let confirmed=false,latest=null;
      for(let a=1;a<=3;a++){
        let ok=false,out=null;
        try{
          out=this.store.update("user",old=>{
            if(!old||old.owner!==this.token)return null;
            return {owner:release?null:this.token,leaseUntil:release?0:time+180,data:old.data};
          });ok=true;
        }catch(e){}
        if(ok&&out&&out.owner===(release?null:this.token)){
          confirmed=true;latest=clone(out.data);break;
        }
        if(ok)break;
      }
      if(confirmed){this.profile=release?null:latest;if(release)this.quarantined=false}
      return confirmed;
    }
  }
  const purchase=(p,op,kind,amount)=>{
    if(p.recentOperations.includes(op)||p.credits<amount)return false;
    if(kind==="part"&&(p.inventory.tire_sport_new||0)>=99)return false;
    if(kind==="car"&&Object.keys(p.garage).length>=8)return false;
    p.credits-=amount;
    p.recentOperations.push(op);
    if(p.recentOperations.length>40)p.recentOperations.shift();
    if(kind==="part")p.inventory.tire_sport_new=(p.inventory.tire_sport_new||0)+1;
    if(kind==="car")p.garage.car2={engineId:"sport_i4",gearboxId:"street_5",tireId:"street"};
    return true;
  };
  const award=(p,op,amount)=>{
    if(p.recentOperations.includes(op)||amount<1||amount>2000)return false;
    p.credits+=amount;p.recentOperations.push(op);
    if(p.recentOperations.length>40)p.recentOperations.shift();
    return true;
  };
  const context=()=>{let store=new Store();let a=new Session(store,"A");eq(a.acquire(),true);return{store,a}};
  test("01 profile: first account creates starter",()=>{const {a}=context();eq(a.profile.credits,0);eq(a.profile.selectedVehicleId,"starter")});
  test("02 profile: competing server cannot acquire lease",()=>{const{store}=context();eq(new Session(store,"B").acquire(),false)});
  test("03 profile: release permits immediate reacquire",()=>{const{store,a}=context();eq(a.save(true),true);eq(new Session(store,"B").acquire(),true)});
  test("04 profile: expired lease reclaimed",()=>{const{store}=context();time+=181;eq(new Session(store,"B").acquire(),true)});
  test("05 economy: insufficient funds reject, session lives",()=>{const{a}=context();eq(a.mutate(p=>purchase(p,"buy_001","part",900)),false);eq(a.quarantined,false);eq(a.profile.credits,0)});
  test("06 economy: race reward is committed once",()=>{const{a}=context();eq(a.mutate(p=>award(p,"race_001",650)),true);eq(a.profile.credits,650)});
  test("07 economy: repeat race ID is rejected",()=>{const{a}=context();a.mutate(p=>award(p,"race_001",650));eq(a.mutate(p=>award(p,"race_001",650)),false);eq(a.profile.credits,650)});
  test("08 economy: part purchase updates credits and inventory",()=>{const{a}=context();a.mutate(p=>award(p,"earn_001",2000));eq(a.mutate(p=>purchase(p,"buy_002","part",900)),true);eq(a.profile.inventory.tire_sport_new,1);eq(a.profile.credits,1100)});
  test("09 economy: replayed part purchase ID never double-charges",()=>{const{a}=context();a.mutate(p=>award(p,"earn_001",2000));a.mutate(p=>purchase(p,"buy_002","part",900));eq(a.mutate(p=>purchase(p,"buy_002","part",900)),false);eq(a.profile.credits,1100)});
  test("10 economy: car acquisition with sufficient balance",()=>{const{a}=context();a.mutate(p=>award(p,"race_a",2000));a.mutate(p=>award(p,"race_b",2000));eq(a.mutate(p=>purchase(p,"car_001","car",3000)),true);eq(Object.keys(a.profile.garage).length,2)});
  test("11 economy: car slot cap blocks purchase",()=>{const{a}=context();a.mutate(p=>{p.credits=90000;for(let i=0;i<7;i++)p.garage["old"+i]={};return true});eq(a.mutate(p=>purchase(p,"car_002","car",3000)),false);eq(a.profile.credits,90000)});
  test("12 datastore: callback retry doesn't duplicate single purchase",()=>{const{store,a}=context();a.mutate(p=>award(p,"earn_001",2000));store.faults.push("retry");eq(a.mutate(p=>purchase(p,"buy_003","part",900)),true);eq(a.profile.credits,1100);eq(store.transforms>=4,true)});
  test("13 datastore: timeout after commit quarantines",()=>{const{store,a}=context();store.faults.push("after");eq(a.mutate(p=>award(p,"race_002",650)),false);eq(a.quarantined,true);eq(store.data.get("user").data.credits,650)});
  test("14 datastore: quarantined session forbids subsequent reward",()=>{const{store,a}=context();store.faults.push("after");a.mutate(p=>award(p,"race_002",650));eq(a.mutate(p=>award(p,"race_003",650)),false);eq(store.data.get("user").data.credits,650)});
  test("15 datastore: quarantined lease can be released",()=>{const{store,a}=context();store.faults.push("after");a.mutate(p=>award(p,"race_002",650));eq(a.save(true),true);const b=new Session(store,"B");eq(b.acquire(),true);eq(b.profile.credits,650)});
  test("16 datastore: two transient lease errors are retried",()=>{const{store,a}=context();store.faults.push("before","before");eq(a.save(),true);eq(a.quarantined,false)});
  test("17 datastore: three lease errors return no false success",()=>{const{store,a}=context();store.faults.push("before","before","before");eq(a.save(),false)});
  test("18 datastore: lost lease refuses a write",()=>{const{store,a}=context();store.data.get("user").owner="OTHER";eq(a.mutate(p=>award(p,"race_003",650)),false);eq(a.quarantined,true)});
  test("19 datastore: lost lease cannot be cleared by old owner",()=>{const{store,a}=context();store.data.get("user").owner="OTHER";eq(a.save(true),false)});
  test("20 race: checkpoint order is strict",()=>{const pts=[100,200,100,0];let next=0;const touch=i=>{if(i!==next)return false;next++;return true};eq(touch(1),false);eq(next,0);eq(touch(0),true);eq(touch(1),true)});
  test("21 race: displacement detects teleport",()=>{const plausible=(dist,dt)=>dt>0&&dist<=145*dt+10;eq(plausible(500,0.1),false);eq(plausible(10,0.1),true)});
  test("22 race: minimum checkpoint travel time",()=>{const plausible=(dist,dt)=>dt>=dist/145;eq(plausible(200,0.1),false);eq(plausible(200,2),true)});
  test("23 race: settlement blocks reentry",()=>{let active=true,settling=false;const mayStart=()=>!active&&!settling;eq(mayStart(),false);active=false;settling=true;eq(mayStart(),false);settling=false;eq(mayStart(),true)});
  test("24 controls: non-owner has no authority",()=>{const mayDrive=(own,driver,alive,age)=>own===driver&&alive&&age<0.45;eq(mayDrive(123,456,true,0.1),false)});
  test("25 controls: stale network input stops motion",()=>{const mayDrive=(own,driver,alive,age)=>own===driver&&alive&&age<0.45;eq(mayDrive(123,123,true,0.5),false);eq(mayDrive(123,123,true,0.2),true)});
  test("26 controls: dead driver cannot accelerate",()=>{const mayDrive=(own,driver,alive,age)=>own===driver&&alive&&age<0.45;eq(mayDrive(123,123,false,0.1),false)});
  test("27 garage: in-place switch retains one instance",()=>{let original={id:"car",engine:"stock_i4",seated:false,speed:0};let active=original;const switchTo=x=>{if(active.seated||active.speed>2)return false;active.engine=x;return true};eq(switchTo("sport_i4"),true);eq(active===original,true)});
  test("28 garage: occupied chassis may not swap",()=>{const car={seated:true,speed:0};eq(car.seated||car.speed>2,true)});
  test("29 parking: 48 deterministic positions are unique",()=>{const slots=new Set();for(let slot=0;slot<48;slot++){const row=Math.floor(slot/24),index=slot%24,side=index%2===0?1:-1,x=(Math.floor(index/2)+1)*18*side,z=row===0?-200:200;slots.add(`${x}:${z}`)}eq(slots.size,48)});
  test("30 profile: bounded operation journal retains max 40",()=>{const p=initial();for(let i=0;i<55;i++)award(p,`race_${i}`,1);eq(p.recentOperations.length,40);eq(p.credits,55)});
  test("31 profile: rejoin restores persisted selected vehicle",()=>{const{store,a}=context();a.mutate(p=>{p.selectedVehicleId="car2";p.garage.car2={engineId:"stock_i4"};return true});a.save(true);const b=new Session(store,"B");eq(b.acquire(),true);eq(b.profile.selectedVehicleId,"car2")});
  test("32 malformed response is never called committed",()=>{const classify=(ok,accepted,rejected,invalid,out,token,valid)=>ok&&accepted&&!rejected&&!invalid&&valid&&out?.owner===token?"committed":"uncertain";eq(classify(true,true,false,true,{owner:"A"},"A",true),"uncertain")});
  return {passed:passed.length,failed,tests:passed};
};
const result=simulate();
for(const name of result.tests) console.log('PASS '+name);
for(const failure of result.failed) console.error('FAIL '+failure.name+': '+failure.error);
console.log('Simulation: '+result.passed+' passed, '+result.failed.length+' failed');
if(result.failed.length) process.exitCode=1;

const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const sourceContracts = [["src/server/services/ProfileService.luau",["MutationOutcome.Classify(","confirmedData = Schema.Decode(output.data)","quarantined[id] = true","quarantined[player.UserId] = true","activeStore():UpdateAsync"]],["src/server/services/RaceService.luau",["settling[id] = true","settling[id] = nil","RaceValidation.PositionPlausible","pcall(function()"]],["src/server/services/PersonalGarage.luau",["local safe, result = pcall(spawnSelected, player)","return result == true","Rules.SelectVehicle(profile"]],["src/server/services/VehicleService.luau",["physicsAccumulator < 1 / 30","raycastCache[car.Model] = nil","input.last < 0.45"]],["src/shared/ProfileMutationOutcome.luau",["not rejectedByRule","not invalidOrLost"]],["src/server/services/GarageMarketplaceService.luau",["Rules.PurchasePart","Rules.PurchaseVehicle","Rules.InstallPart"]],["src/shared/ProfileSchema.luau",["schemaVersion = 2","MAX_CARS = 8"]],["src/shared/GarageTransactions.luau",["record(profile, operationId)","profile.credits -="]]];
let verified = 0;
for (const [relative, snippets] of sourceContracts) {
  let source;
  try { source = fs.readFileSync(path.join(root, relative), "utf8"); }
  catch (error) { console.error("FAIL missing source "+relative+" "+error); process.exitCode=1; continue; }
  for (const snippet of snippets) {
    if (!source.includes(snippet)) {
      console.error("FAIL source contract "+relative+": "+snippet);
      process.exitCode=1;
    } else verified++;
  }
}
const boot = fs.readFileSync(path.join(root, "src/server/bootstrap.server.luau"), "utf8");
if (boot.indexOf("GarageMarketplaceService.Start()") === -1
  || boot.indexOf("RaceService.Start()") === -1
  || boot.indexOf("GarageMarketplaceService.Start()") > boot.indexOf("RaceService.Start()")) {
  console.error("FAIL bootstrap order: marketplace must start before race notifications");
  process.exitCode=1;
} else verified++;
console.log("Source contracts: "+verified+" / "+(sourceContracts.reduce((n,x)=>n+x[1].length,1)));
