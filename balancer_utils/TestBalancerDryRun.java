package org.apache.hadoop.hdfs.server.balancer;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hdfs.DFSConfigKeys;
import org.apache.hadoop.hdfs.HdfsConfiguration;
import org.apache.hadoop.hdfs.protocol.ClientProtocol;
import org.apache.hadoop.hdfs.protocol.DatanodeInfo;
import org.apache.hadoop.hdfs.server.datanode.DataNode;
import org.apache.hadoop.net.NetworkTopology;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.hdfs.MiniDFSCluster;
import org.apache.hadoop.test.GenericTestUtils;
import org.apache.hadoop.hdfs.NameNodeProxies;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.commons.logging.impl.Log4JLogger;

import org.apache.log4j.Level;

import org.junit.Assert;
import org.junit.Test;

import java.io.*;
import java.util.*;


public class TestBalancerDryRun {
    private static final Log LOG = LogFactory.getLog(TestBalancerDryRun.class);
    ClientProtocol client = null;
    final static long CAPACITY = 5000L;
    final static String RACK0 = "/rack0";
    final static String RACK1 = "/rack1";
    final static String RACK2 = "/rack2";
    final private static String fileName = "/tmp.txt";
    final static Path filePath = new Path(fileName);
    TestBalancer balancerTest = new TestBalancer();
    private static final Random r = new Random();
    static {
        GenericTestUtils.setLogLevel(Balancer.LOG, Level.ALL);
        ((Log4JLogger)Balancer.LOG).getLogger().setLevel(Level.ALL);
        ((Log4JLogger)Dispatcher.LOG).getLogger().setLevel(Level.DEBUG);
    }

    static {
        initTestSetup();
    }

    public static void initTestSetup() {
        // do not create id file since it occupies the disk space
        NameNodeConnector.setWrite2IdFile(false);
    }
    final static long simulationFactor = (1024 * 1024);
    public static HashMap<String,DatanodeInfo> populateDataNodes(String[] args) throws Exception {
        FileReader fr =
                new FileReader("/Users/smajeti/Downloads/dfsadmin_report");
        BufferedReader br = new BufferedReader(fr);
        String sCurrentLine;

      /*Configured Capacity: 744103084032 (693 GB)
        Present Capacity: 547064620106 (509.49 GB)
        DFS Remaining: 497019884516 (462.89 GB)
        DFS Used: 50044735590 (46.61 GB)
        DFS Used%: 9.15%
              Under replicated blocks: 0
        Blocks with corrupt replicas: 0
        Missing blocks: 0
        Missing blocks (with replication factor 1): 0

              -------------------------------------------------
              Live datanodes (7):

        Name: 172.25.37.16:50010 (c1265-node4.hwx.com)
        Hostname: c1265-node4.hwx.com
        Rack: /OLD_RACK1
        Decommission Status : Normal
        Configured Capacity: 106300440576 (99 GB)
        DFS Used: 6858915840 (6.39 GB)
        Non DFS Used: 44332920832 (41.29 GB)
        DFS Remaining: 54840168614 (51.07 GB)
        DFS Used%: 6.45%
              DFS Remaining%: 51.59%
              Configured Cache Capacity: 0 (0 B)
        Cache Used: 0 (0 B)
        Cache Remaining: 0 (0 B)
        Cache Used%: 100.00%
              Cache Remaining%: 0.00%
              Xceivers: 6
        Last contact: Mon Feb 04 12:40:07 UTC 2019
        Last Block Report: Mon Feb 04 11:23:37 UTC 2019
        */
        boolean name_node_records_started = false;
        boolean first_data_node_record = true;
        String ipAddr;
        String hostName="";
        String decommStatus ="";
        String rack="/default-rack";
        long capacity=0l;
        long dfsUsed=0l;
        long nonDfsUsed=0l;
        long remaining=0l;
        HashMap<String,DatanodeInfo> hashMap = new HashMap();
        String location = NetworkTopology.DEFAULT_RACK;
        String softwareVersion;
        List<String> dependentHostNames = new LinkedList<String>();
        while ((sCurrentLine = br.readLine()) != null) {
            //System.out.println(sCurrentLine);
            //skip all the lines before start of first DataNode info (Name tag)
            if (!sCurrentLine.contains("Name:") && !name_node_records_started) {
                continue;
            } else {
                name_node_records_started = true;
                if (sCurrentLine.trim().isEmpty()) {
                    continue;
                }
                if (sCurrentLine.contains("Name:")) {
                    ipAddr = sCurrentLine.split(" ")[1].split(":")[0];
                    String ipcP = sCurrentLine.split(" ")[0].split(":")[0];
                    if(!first_data_node_record) {
                        DatanodeInfo dnInfo = new DatanodeInfo(
                                ipAddr,
                                hostName,
                                null,
                                0,
                                0,
                                0,
                                0,
                                capacity,
                                dfsUsed,
                                nonDfsUsed,
                                remaining,
                                0l,
                               0l,
                                0l,
                                0l,
                                0l,
                                0,
                                rack,
                                DatanodeInfo.AdminStates.fromValue(decommStatus),
                                0l,
                                0l);
                        hashMap.put(hostName,dnInfo);
                    }else{
                        first_data_node_record = false;
                    }
                }else if(sCurrentLine.contains("Hostname:")){
                    hostName = sCurrentLine.split(":")[1].trim();
                }else if(sCurrentLine.contains("Rack:")){
                    rack = sCurrentLine.split(":")[1].trim();
                }else if(sCurrentLine.contains("Decommission Status :")){
                    decommStatus = sCurrentLine.split(":")[1].trim();
                }else if(sCurrentLine.contains("Configured Capacity:")){
                    capacity = getLongCustom(sCurrentLine.split(" ")[2].trim());
                }else if(sCurrentLine.startsWith("DFS Used:")){
                    dfsUsed = getLongCustom(sCurrentLine.split(" ")[2].trim());
                }else if(sCurrentLine.startsWith("Non DFS Used:")){
                    nonDfsUsed = getLongCustom(sCurrentLine.split(" ")[3].trim());
                }
                //System.out.println(sCurrentLine);
            }
        }
        hashMap.forEach((k,v) -> System.out.println(v.getIpAddr()+" "+v.getHostName()+" "+v.getCapacity()));
        return hashMap;
    }

    /** This test start a cluster with specified number of nodes,
     * and fills it to be 30% full (with a single file replicated identically
     * to all datanodes);
     * It then adds one new empty node and starts balancing.
     *
     * @param conf - configuration
     * @param capacities - array of capacities of original nodes in cluster
     * @param racks - array of racks for original nodes in cluster
     * @param newCapacity - new node's capacity
     * @param newRack - new node's rack
     * @param nodes - information about new nodes to be started.
     * @param useTool - if true run test via Cli with command-line argument
     *   parsing, etc.   Otherwise invoke balancer API directly.
     * @param useFile - if true, the hosts to included or excluded will be stored in a
     *   file and then later read from the file.
     * @throws Exception
     */
    private void findThreshold(Configuration conf, long[] capacities,
                               String[] racks, long newCapacity, String newRack, TestBalancer.NewNodeInfo nodes,
                               boolean useTool, boolean useFile) throws Exception {
        LOG.info("capacities = " + balancerTest.long2String(capacities));
        LOG.info("racks      = " + Arrays.asList(racks));
        LOG.info("newCapacity= " + newCapacity);
        LOG.info("newRack    = " + newRack);
        LOG.info("useTool    = " + useTool);
        Assert.assertEquals(capacities.length, racks.length);
        int numOfDatanodes = capacities.length;
        MiniDFSCluster cluster = null;

        try {
            cluster = new MiniDFSCluster.Builder(conf)
                    .numDataNodes(capacities.length)
                    .racks(racks)
                    .simulatedCapacities(capacities)
                    .build();
            cluster.getConfiguration(0).setInt(DFSConfigKeys.DFS_REPLICATION_KEY,
                    DFSConfigKeys.DFS_REPLICATION_DEFAULT);
            conf.setInt(DFSConfigKeys.DFS_REPLICATION_KEY,
                    DFSConfigKeys.DFS_REPLICATION_DEFAULT);
            cluster.waitClusterUp();
            cluster.waitActive();
            client = NameNodeProxies.createProxy(conf, cluster.getFileSystem(0).getUri(),
                    ClientProtocol.class).getProxy();

            long totalCapacity = TestBalancer.sum(capacities);

            // fill up the cluster to be 30% full
            long totalUsedSpace = totalCapacity * 3 / 10;
            TestBalancer.createFile(cluster, filePath, totalUsedSpace / numOfDatanodes,
                    (short) numOfDatanodes, 0);
            cluster.getFileSystem().getDataNodeStats();
            if (nodes == null) { // there is no specification of new nodes.
                // start up an empty node with the same capacity and on the same rack
                cluster.startDataNodes(conf, 1, true, null,
                        new String[]{newRack}, null, new long[]{newCapacity});
                totalCapacity += newCapacity;
            } else {
                //if running a test with "include list", include original nodes as well
                if (nodes.getNumberofIncludeNodes() > 0) {
                    for (DataNode dn : cluster.getDataNodes())
                        nodes.getNodesToBeIncluded().add(dn.getDatanodeId().getHostName());
                }
                String[] newRacks = new String[nodes.getNumberofNewNodes()];
                long[] newCapacities = new long[nodes.getNumberofNewNodes()];
                for (int i = 0; i < nodes.getNumberofNewNodes(); i++) {
                    newRacks[i] = newRack;
                    newCapacities[i] = newCapacity;
                }
                // if host names are specified for the new nodes to be created.
                if (nodes.getNames() != null) {
                    cluster.startDataNodes(conf, nodes.getNumberofNewNodes(), true, null,
                            newRacks, nodes.getNames(), newCapacities);
                    totalCapacity += newCapacity * nodes.getNumberofNewNodes();
                } else {  // host names are not specified
                    cluster.startDataNodes(conf, nodes.getNumberofNewNodes(), true, null,
                            newRacks, null, newCapacities);
                    totalCapacity += newCapacity * nodes.getNumberofNewNodes();
                    //populate the include nodes
                    if (nodes.getNumberofIncludeNodes() > 0) {
                        int totalNodes = cluster.getDataNodes().size();
                        for (int i = 0; i < nodes.getNumberofIncludeNodes(); i++) {
                            nodes.getNodesToBeIncluded().add(cluster.getDataNodes().get(
                                    totalNodes - 1 - i).getDatanodeId().getXferAddr());
                        }
                    }
                    //polulate the exclude nodes
                    if (nodes.getNumberofExcludeNodes() > 0) {
                        int totalNodes = cluster.getDataNodes().size();
                        for (int i = 0; i < nodes.getNumberofExcludeNodes(); i++) {
                            nodes.getNodesToBeExcluded().add(cluster.getDataNodes().get(
                                    totalNodes - 1 - i).getDatanodeId().getXferAddr());
                        }
                    }
                }
            }
            // run balancer and validate results
            BalancerParameters.Builder pBuilder =
                    new BalancerParameters.Builder();
            if (nodes != null) {
                pBuilder.setExcludedNodes(nodes.getNodesToBeExcluded());
                pBuilder.setIncludedNodes(nodes.getNodesToBeIncluded());
                pBuilder.setRunDuringUpgrade(false);
            }
            BalancerParameters p = pBuilder.build();

            int expectedExcludedNodes = 0;
            if (nodes != null) {
                if (!nodes.getNodesToBeExcluded().isEmpty()) {
                    expectedExcludedNodes = nodes.getNodesToBeExcluded().size();
                } else if (!nodes.getNodesToBeIncluded().isEmpty()) {
                    expectedExcludedNodes =
                            cluster.getDataNodes().size() - nodes.getNodesToBeIncluded().size();
                }
            }

            // run balancer and validate results
            if (useTool) {
                balancerTest.runBalancerCli(conf, totalUsedSpace, totalCapacity, p, useFile, expectedExcludedNodes);
            } else {
                balancerTest.runBalancer(conf, totalUsedSpace, totalCapacity, p, expectedExcludedNodes);
            }
        } finally {
            if (cluster != null) {
                cluster.shutdown();
            }
        }
    }

    private static long getLongCustom(String value) {
        return Long.parseLong(value)/simulationFactor;
    }

    public static void runSimulation(String[] args) throws  Exception{
        final Configuration conf = new HdfsConfiguration();
        TestBalancerDryRun testBalancerDryRun = new TestBalancerDryRun();
        HashMap<String,DatanodeInfo> hashMap = TestBalancerDryRun.populateDataNodes(args);
        //TBD block size and balancer parameters
        TestBalancer.initConf(conf);
        //fetch customer block size value
        long configuredBlockSizeValue = 128 * 1024 *1024 ;
        conf.setLong(DFSConfigKeys.DFS_NAMENODE_MIN_BLOCK_SIZE_KEY,configuredBlockSizeValue/simulationFactor/2);
        Set<String> excludeHosts = new HashSet<String>();
        excludeHosts.add( "datanodeY");
        excludeHosts.add( "datanodeZ");
        testBalancerDryRun.findThreshold(conf, new long[]{CAPACITY, CAPACITY}, new String[]{RACK0, RACK1}, CAPACITY, RACK2,
                new TestBalancer.HostNameBasedNodes(new String[] {"datanodeX", "datanodeY", "datanodeZ"},
                        excludeHosts, BalancerParameters.DEFAULT.getIncludedNodes()),
                false, false);
    }

    public static void main(String[] args) throws Exception{
        runSimulation(args);
    }
}
