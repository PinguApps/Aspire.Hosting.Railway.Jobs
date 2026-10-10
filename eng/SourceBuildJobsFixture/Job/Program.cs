System.Console.WriteLine("PIN646_SOURCE_BUILD_" + System.IO.File.ReadAllText("proof.txt").Trim());
string scenario = System.Environment.GetEnvironmentVariable("PIN646_SCENARIO") ?? "success";
if (scenario == "timeout")
{
    for (int iteration = 0; iteration < 5; iteration++)
    {
        System.Console.WriteLine("PIN646_JOB_LONG_RUNNING");
        System.Threading.Thread.Sleep(60000);
    }
}
System.Threading.Thread.Sleep(2000);
System.Console.WriteLine(scenario switch
{
    "failure" => "PIN646_JOB_FAILURE",
    "cron" => "PIN646_SCHEDULED_SUCCESS",
    _ => "PIN646_JOB_SUCCESS",
});
System.Environment.Exit(scenario == "failure" ? 7 : 0);
