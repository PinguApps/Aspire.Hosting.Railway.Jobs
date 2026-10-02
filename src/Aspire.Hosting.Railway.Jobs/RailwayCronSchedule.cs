using System.Globalization;

namespace Aspire.Hosting.Railway.Jobs;

internal static class RailwayCronSchedule
{
    internal static void Validate(string schedule)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(schedule);
        string[] fields = schedule.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (fields.Length != 5)
        {
            throw new ArgumentException("Use a five-field UTC cron schedule.", nameof(schedule));
        }

        SortedSet<int> minutes = ParseField(fields[0], 0, 59);
        _ = ParseField(fields[1], 0, 23);
        _ = ParseField(fields[2], 1, 31);
        _ = ParseField(fields[3], 1, 12);
        _ = ParseField(fields[4], 0, 6);

        int previous = minutes.Max - 60;
        foreach (int minute in minutes)
        {
            if (minute - previous < 5)
            {
                throw new ArgumentException("Scheduled minute values must be at least five minutes apart, including the hour boundary.", nameof(schedule));
            }

            previous = minute;
        }
    }

    private static SortedSet<int> ParseField(string field, int minimum, int maximum)
    {
        SortedSet<int> values = [];
        foreach (string item in field.Split(','))
        {
            string[] stepped = item.Split('/');
            if (stepped.Length > 2)
            {
                throw InvalidSchedule();
            }

            int step = stepped.Length == 2 ? ParseNumber(stepped[1], 1, maximum + 1) : 1;
            string[] range = stepped[0].Split('-');
            int first;
            int last;
            if (stepped[0] == "*")
            {
                first = minimum;
                last = maximum;
            }
            else
            {
                first = ParseNumber(range[0], minimum, maximum);
                last = range.Length == 2 ? ParseNumber(range[1], first, maximum) : first;
                if (range.Length > 2 || (stepped.Length == 2 && range.Length == 1))
                {
                    throw InvalidSchedule();
                }
            }

            for (int value = first; value <= last; value += step)
            {
                values.Add(value);
            }
        }

        return values;
    }

    private static int ParseNumber(string value, int minimum, int maximum)
    {
        if (!int.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out int parsed) || parsed < minimum || parsed > maximum)
        {
            throw InvalidSchedule();
        }

        return parsed;
    }

    private static ArgumentException InvalidSchedule()
    {
        return new ArgumentException("Use numeric UTC cron fields with *, ranges, lists, or steps on ranges/wildcards.", "schedule");
    }
}
