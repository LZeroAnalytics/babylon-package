import { useState, useEffect } from 'react';
import { Activity, Users, Shield } from 'lucide-react';
import axios from 'axios';

interface StatsData {
  activeDelegations: number;
  totalStakers: number;
  finalityProviders: number;
  currentBlockHeight: number;
}

interface Block {
  height: number;
  timestamp: string;
  transactions: number;
  proposer: string;
}

function App() {
  const [stats, setStats] = useState<StatsData>({
    activeDelegations: 0,
    totalStakers: 0,
    finalityProviders: 0,
    currentBlockHeight: 0
  });
  const [blocks, setBlocks] = useState<Block[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const rpcUrl = import.meta.env.VITE_BABYLON_RPC || 'http://localhost:26657';
        
        const statusResponse = await axios.get(`${rpcUrl}/status`);
        const currentHeight = parseInt(statusResponse.data.result.sync_info.latest_block_height);
        
        const stakingResponse = await axios.get(`${import.meta.env.VITE_STAKING_API || 'http://localhost:8080'}/v1/stats`);
        
        setStats({
          activeDelegations: stakingResponse.data.active_delegations || 0,
          totalStakers: stakingResponse.data.total_stakers || 0,
          finalityProviders: stakingResponse.data.finality_providers || 0,
          currentBlockHeight: currentHeight
        });

        const blocksData: Block[] = [];
        for (let i = 0; i < 10; i++) {
          const blockHeight = currentHeight - i;
          try {
            const blockResponse = await axios.get(`${rpcUrl}/block?height=${blockHeight}`);
            const block = blockResponse.data.result.block;
            blocksData.push({
              height: blockHeight,
              timestamp: new Date(block.header.time).toLocaleString(),
              transactions: block.data.txs ? block.data.txs.length : 0,
              proposer: block.header.proposer_address.substring(0, 8) + '...'
            });
          } catch (error) {
            console.error(`Error fetching block ${blockHeight}:`, error);
          }
        }
        setBlocks(blocksData);
        setLoading(false);
      } catch (error) {
        console.error('Error fetching data:', error);
        setLoading(false);
      }
    };

    fetchData();
    const interval = setInterval(fetchData, 10000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-xl">Loading Babylon Explorer...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div className="flex items-center">
              <h1 className="text-2xl font-bold text-orange-600">Babylon Explorer</h1>
            </div>
            <nav className="flex space-x-8">
              <a href="#" className="text-gray-900 hover:text-orange-600">Home</a>
              <a href="#" className="text-gray-500 hover:text-orange-600">Blockchain</a>
              <a href="#" className="text-gray-500 hover:text-orange-600">BTC Staking</a>
              <a href="#" className="text-gray-500 hover:text-orange-600">Epochs</a>
              <a href="#" className="text-gray-500 hover:text-orange-600">Proposals</a>
            </nav>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-gradient-to-r from-orange-100 to-orange-50 rounded-lg p-8 mb-8">
          <h2 className="text-3xl font-bold text-center mb-4">Faucet now live on Babylon Explorer!</h2>
          <p className="text-center text-gray-600">
            Claim free tBBN and explore the latest features — including Token, Contract details, and IBC Relayer tracking.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div className="bg-orange-100 rounded-lg p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Active Delegations</p>
                <p className="text-2xl font-bold">{stats.activeDelegations.toLocaleString()} BTC</p>
                <p className="text-sm text-green-600">↗ 0.098%</p>
              </div>
              <Activity className="h-8 w-8 text-orange-600" />
            </div>
          </div>

          <div className="bg-orange-100 rounded-lg p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Stakers</p>
                <p className="text-2xl font-bold">{stats.totalStakers.toLocaleString()}</p>
                <p className="text-sm text-gray-500">0%</p>
              </div>
              <Users className="h-8 w-8 text-orange-600" />
            </div>
          </div>

          <div className="bg-orange-100 rounded-lg p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Finality Providers</p>
                <p className="text-2xl font-bold">{stats.finalityProviders}</p>
                <p className="text-sm text-gray-500">0%</p>
              </div>
              <Shield className="h-8 w-8 text-orange-600" />
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <div className="bg-white rounded-lg border p-6">
            <h3 className="text-lg font-semibold mb-4">Current Block Height</h3>
            <div className="text-3xl font-bold text-orange-600 mb-4">{stats.currentBlockHeight.toLocaleString()}</div>
            <div className="text-sm text-gray-600">Average Block Created: 6.9 secs</div>
          </div>

          <div className="bg-white rounded-lg border p-6">
            <h3 className="text-lg font-semibold mb-4">Latest Blocks</h3>
            <div className="space-y-3">
              {blocks.slice(0, 5).map((block) => (
                <div key={block.height} className="flex justify-between items-center py-2 border-b border-gray-100">
                  <div>
                    <div className="font-medium">#{block.height}</div>
                    <div className="text-sm text-gray-500">{block.timestamp}</div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm">{block.transactions} txs</div>
                    <div className="text-xs text-gray-500">{block.proposer}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

export default App;
