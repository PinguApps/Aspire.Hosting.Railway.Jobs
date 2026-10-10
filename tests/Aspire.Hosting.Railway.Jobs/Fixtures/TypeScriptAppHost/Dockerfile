FROM busybox:1.37.0
ARG JOB_MESSAGE=backup
RUN echo "$JOB_MESSAGE" > /job-message
CMD ["sh", "-c", "cat /job-message; exit 0"]
