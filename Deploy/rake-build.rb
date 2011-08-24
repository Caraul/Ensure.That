#--------------------------------------
# Dependencies
#--------------------------------------
require 'albacore'
#--------------------------------------
# Debug
#--------------------------------------
#ENV.each {|key, value| puts "#{key} = #{value}" }
#--------------------------------------
# My environment vars
#--------------------------------------
@env_buildversion = "0.1.1" + (ENV['env_buildnumber'].to_s.empty? ? "" : ".#{ENV['env_buildnumber'].to_s}")
@env_buildconfigname = ENV['env_buildconfigname'].empty? ? "Release" : ENV['env_buildconfigname']
@env_buildfolderpath = ENV['env_buildfolderpath']

@env_nugetPublishApiKey = ENV['env_nugetPublishApiKey']
@env_nugetPublishUrl = ENV['env_nugetPublishUrl']
@env_nugetSourceUrl = ENV['env_nugetSourceUrl']
#--------------------------------------
@env_solutionfolderpath = "../Solution/"
@env_solutionname = 'Ensure.That'
@env_projectname = 'EnsureThat'
@env_buildname = "#{@env_solutionname}-v#{@env_buildversion}-#{@env_buildconfigname}"
@env_buildfolderpath = "#{@env_buildfolderpath}builds/#{@env_buildname}/"
@env_binariesfolderpath = "#{@env_buildfolderpath}binaries"
#--------------------------------------
# Albacore flow controlling tasks
#--------------------------------------
task :ci => [:installMissingNuGets, :buildIt, :testIt, :packageIt, :deployIt]

task :local => [:buildIt, :testIt, :packageIt]
#--------------------------------------
task :buildIt => [:versionIt, :compileIt, :copyBinaries]

task :testIt => [:runUnitTests]

task :packageIt => [:createZip, :createNuGet, :createNuGetSource]

task :deployIt => [:publishNuGet, :publishNuGetSource]
#--------------------------------------
# Albacore tasks
#--------------------------------------
exec :installMissingNuGets do |cmd|
  FileList["#{@env_solutionfolderpath}**/packages.config"].each { |filepath|
    cmd.command = "NuGet.exe"
    cmd.parameters = "i #{filepath} -o #{@env_solutionfolderpath}/packages -s #{@env_nugetSourceUrl}"
  }
end

assemblyinfo :versionIt do |asm|
  sharedAssemblyInfoPath = "#{@env_solutionfolderpath}SharedAssemblyInfo.cs"
  
  asm.input_file = sharedAssemblyInfoPath
  asm.output_file = sharedAssemblyInfoPath
  asm.version = @env_buildversion
  asm.file_version = @env_buildversion  
end

task :createCleanBuildFolders do
  FileUtils.rm_rf(@env_buildfolderpath)
  FileUtils.mkdir_p(@env_binariesfolderpath)
end

msbuild :compileIt => [:createCleanBuildFolders] do |msb|
  msb.properties :configuration => @env_buildconfigname
  msb.targets :Clean, :Build
  msb.solution = "#{@env_solutionfolderpath}#{@env_solutionname}.sln"
end

task :copyBinaries do
  FileUtils.cp_r(FileList["#{@env_solutionfolderpath}Source/#{@env_projectname}/bin/#{@env_buildconfigname}/*.*"], @env_binariesfolderpath)
end

nunit :runUnitTests do |nunit|
  nunit.command = "#{@env_solutionfolderpath}packages/NUnit.2.5.10.11092/tools/nunit-console.exe"
  nunit.options "/framework=v4.0.30319","/xml=#{@env_buildfolderpath}NUnit-#{@env_projectname}-UnitTests.xml"
  nunit.assemblies = FileList["#{@env_solutionfolderpath}Tests/**/#{@env_buildconfigname}/*.UnitTests.dll"].exclude(/obj\//)
end

zip :createZip do |zip|
  zip.directories_to_zip "#{@env_binariesfolderpath}"
  zip.output_file = "#{@env_buildname}.zip"
  zip.output_path = @env_buildfolderpath
end

exec :createNuGet do |cmd|
  cmd.command = "NuGet.exe"
  cmd.parameters = "pack #{@env_solutionname}.nuspec -version #{@env_buildversion} -nodefaultexcludes -basepath #{@env_binariesfolderpath} -outputdirectory #{@env_buildfolderpath}"
end

exec :createNuGetSource do |cmd|
  cmd.command = "NuGet.exe"
  cmd.parameters = "pack #{@env_solutionname}.Source.nuspec -version #{@env_buildversion} -nodefaultexcludes -basepath #{@env_solutionfolderpath} -outputdirectory #{@env_buildfolderpath}"
end

exec :publishNuGet do |cmd|
  cmd.command = "NuGet.exe"
  cmd.parameters = "push #{@env_buildfolderpath}#{@env_solutionname}.#{@env_buildversion}.nupkg #{@env_nugetPublishApiKey} -src #{@env_nugetPublishUrl}"
end

exec :publishNuGetSource do |cmd|
  cmd.command = "NuGet.exe"
  cmd.parameters = "push #{@env_buildfolderpath}#{@env_solutionname}.Source.#{@env_buildversion}.nupkg #{@env_nugetPublishApiKey} -src #{@env_nugetPublishUrl}"
end