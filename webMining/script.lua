CRLF = "\n"
gnuplot = "c:\\Progra~1\\gnuplot\\bin\\gnuplot.exe"
--gnuplot = "/usr/bin/gnuplot"

term = {}
term["png"] = ".png"
term["postscript"]=".ps"
term["default"]="png"

displayResults = function(dsre,method,dir,filename) 
  local j=0
  local regions = dsre:regionCount()
  local outp = io.open(dir..filename,"w")
  
  outp:write("<pre> timestamp: ");
  outp:write(os.clock());
  outp:write("</pre><br/>\n");
  
  if method=="srde" then
    local tps = dsre:getTps()
    if #tps then
      outp:write("<style>table {border-collapse: collapse;} table, td, th {border: 1px solid black;}</style>")
      outp:write("<font face=courier><img src='",filename,".tps",term[term["default"]],"' /><br />",CRLF)
      outp:write("<textarea>",CRLF)
      outp:write(tps[1])
      for k=2,#tps do
        outp:write(",",tps[k])
      end
      outp:write("</textarea><br />")
    end
  end
  for i=1,regions do
    local dr = dsre:getDataRegion(i-1)
    if dr:isContent() then
      outp:write("<font color=red><b>*** Content detected ***</b></font><br>",CRLF)
    end
    local rows = dr:recordCount()
    local cols = dr:recordSize()
    outp:write("<table><tr><th> region ",i,"</th><th> rows ",rows,"</th><th> cols ",cols,"</th></tr></table>",CRLF)
    
    if (rows > 0) and (cols > 0) then 
      outp:write("<table>",CRLF)
      print(rows)
      for r=1,rows do
        outp:write("<tr>")
        local record = dr:getRecord(r-1)
        for c=1,cols do
          if record[c] then
            outp:write("<td>",record[c]:toString(),"</td>")
          else
            outp:write("<td>[filler]</td>")
          end
        end
        outp:write("</tr>",CRLF)
        j = j + 1
      end
      outp:write("</table><br />",CRLF)
    end
    
    local tps = dr:getTps()
    local linReg = dr:getLinearRegression()
    if #tps then
      outp:write("<img src='",filename,".region",i,term[term["default"]],"' /><br />",CRLF)
      outp:write(string.format("interval: [%d; %d], size: %d, angle: %.2f, score: %.2f<br/>",dr:getStartPos(),dr:getEndPos(),dr:size(),math.atan(math.abs(linReg.a))*180/math.pi,dr:getScore()),CRLF)
      outp:write("<textarea>",CRLF)
      outp:write(tps[1])
      for k=2,#tps do
        outp:write(",",tps[k])
      end
      outp:write("</textarea><br />",CRLF)
    end
    outp:write(CRLF)
  end
  outp:write(regions," regions, ",j," records.",CRLF)
  outp:write("</font><hr/><br/>",CRLF)
  outp:close()
end

plotSequences = function(dsre,output,filename)
  local method = "srde"
  local regions = dsre:regionCount()
  local tps = dsre:getTps()

  f = io.open(filename..".plot.txt","w")
  if output == "file" then
    f:write("set term ",term["default"],CRLF)
  else
    f:write("set mouse",CRLF)
    f:write("set multiplot layout ",regions+1,",1",CRLF)
  end

  f:write("set output \"",filename,".tps",term[term["default"]],"\"",CRLF)
  f:write("set autoscale fix",CRLF)
  f:write("set style line 1 lc rgb \'#0060ad\' lt 1 lw 1 pt 7 ps 0.5",CRLF)
  f:write("plot '-' with linespoints ls 1 title 'Full TPS'",CRLF)
  for i=1,#tps do
        f:write(i-1,"\t",tps[i],CRLF)
  end
  f:write("e",CRLF)

  for i=1,regions do
    local dr = dsre:getDataRegion(i-1)
    local linReg = dr:getLinearRegression()
    tps = dr:getTps()
    if #tps then
      f:write("set output \"",filename,".region",i,term[term["default"]],"\"",CRLF)
      f:write("set autoscale fix",CRLF)
      f:write("set style line 1 lc rgb \'#0060ad\' lt 1 lw 1 pt 7 ps 0.5",CRLF)
      f:write("plot ",linReg.a,"*x+",linReg.b," with lines title 'Linear regression','-' with linespoints ls 1 title \'Region ",i,"\'",CRLF)
      for j=1,#tps do
        f:write(j-1,"\t",tps[j],CRLF)
      end
      f:write("e",CRLF)
    end
  end
  f:write("unset multiplot",CRLF)
  f:write("quit",CRLF)
  f:close()
  os.execute(gnuplot.." "..filename..".plot.txt")
end

processTestBed = function(dir)
  local t, popen = {}, io.popen
  

  for filename in popen('ls -a "'..dir..'"/*.htm*'):lines() do
    local d, fn, ext = filename:match("(.-)([^\\/]-%.?([^%.\\/]*))$")
    local output = d.."srde/"..fn
    
    print(string.format("Loading DOM tree: %s",filename),CRLF)
    local dom = DOM.new(filename)
    local dsre = DSRE.new()
    
    --print("Extracting records.")
    local start = os.clock()
    dsre:extract(dom)
    print(string.format("elapsed time: %.2f",os.clock() - start),CRLF)
    
    --print("Outputting results.")
    displayResults(dsre,"srde",d.."srde/",fn)
    
    --print("Plotting graphs.")
    plotSequences(dsre,"file",output)
  end
end

processFile = function(filename)
    print(string.format("Loading DOM tree: %s",filename),CRLF)
    local dom = DOM.new(filename)
    local dsre = DSRE.new()
    
    print("Extracting records.")
    local start = os.clock()
    dsre:extract(dom)
    print(string.format("elapsed time: %.2f",os.clock() - start),CRLF)
    
    print("Outputting results.")
    displayResults(dsre,"srde","./","output.html")
    
    print("Plotting graphs.")
    plotSequences(dsre,"file","output.html")
    
    dom:printHTML()
    dsre:printTps()
end

if #args > 4 then
  processFile(args[5])
  do return end
end

processTestBed("../../datasets/clustvx")
--do return end
processTestBed("../../datasets/yamada")
-- [[
processTestBed("../../datasets/zhao3")
processTestBed("../../datasets/tpsf")
processTestBed("../../datasets/TWEB_TB2")
processTestBed("../../datasets/TWEB_TB3")
processTestBed("../../datasets/alvarez")
processTestBed("../../datasets/wien")
processTestBed("../../datasets/zhao1")
processTestBed("../../datasets/zhao2")
processTestBed("../../datasets/trieschnigg1")
processTestBed("../../datasets/trieschnigg2")
-- ]]

exit()
