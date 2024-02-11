using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using YamlDotNet.Serialization;

namespace ProjectTests.Infrastructure
{
    public class ActionsWorkflow
    {
        JsonNode root;

        public ActionsWorkflow(string path)
        {
            var deserializer = new Deserializer();
            var yamlObject = deserializer.Deserialize(File.ReadAllText(path));

            var json = JsonSerializer.Serialize(yamlObject, new JsonSerializerOptions { WriteIndented = true });
            root = JsonSerializer.Deserialize<JsonNode>(json);

            var options = new JsonSerializerOptions()
            {
                PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
            };

            Name = root["name"].GetValue<string>();
            RunName = root["run-name"]?.GetValue<string>();
            On = root["on"].AsObject();
            Permissions = JsonSerializer.Deserialize<IReadOnlyDictionary<string, string>>(root["permissions"]);
            Env = JsonSerializer.Deserialize<IReadOnlyDictionary<string, string>>(root["env"]);

            Jobs = root["jobs"].AsObject().Select(pair =>
            {
                var job = JsonSerializer.Deserialize<WorkflowJob>(pair.Value, options);
                job.Id = pair.Key;
                return job;
            })
            .ToArray();
        }

        public string Name { get; }
        public string RunName { get; }
        public JsonObject On { get; }
        public IReadOnlyDictionary<string, string> Permissions { get; }
        public IReadOnlyDictionary<string, string> Env { get; }

        public WorkflowJob[] Jobs { get; }
    }

    public class WorkflowJob
    {
        public string Id { get; set; }
        public string Name { get; set; }
        [JsonPropertyName("runs-on")]
        public string RunsOn { get; set; }
        public JsonObject Strategy { get; set; }
        public JobStep[] Steps { get; set; }
    }

    public class JobStep
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string If { get; set; }
        public string Shell { get; set; }
        public IReadOnlyDictionary<string, string> Env { get; set; }
        public string Run { get; set; }
        public string Uses { get; set; }
        public IReadOnlyDictionary<string, string> With { get; set; }
    }
}